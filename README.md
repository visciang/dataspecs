# dataspecs

![CI](https://github.com/visciang/dataspecs/workflows/CI/badge.svg) [![Coverage Status](https://coveralls.io/repos/github/visciang/dataspecs/badge.svg?branch=main)](https://coveralls.io/github/visciang/dataspecs?branch=main)

Typespec based data loader and validator (inspired by [forma](https://github.com/soundtrackyourbrand/forma)).

DataSpecs **validate and load** elixir data into a more structured form
by trying to map it to conform to a **typespec**. It support most typespec
specification: **basic** types, **literal** types, **built-in** types, **union** type,
**parametrized** types, **maps**, **remote** types and **user defined** types.

It can be used to validate some elixir data against a typespec or it
can be useful when interfacing with external data sources that provide
you data as JSON or MessagePack, but that you wish to validate transform
into either proper structs or richer data types without a native
JSON representation (such as dates or sets) in your application.

## Usage

```elixir
defmodule Person do
  @enforce_keys [:name, :surname]
  defstruct [:name, :surname, :gender, :address]

  @type t :: %__MODULE__{
    name: String.t(),
    surname: String.t(),
    gender: option(:male | :female | :other),
    address: option(nonempty_list(Address.t()))
  }

  @type option(x) :: nil | x
end

defmodule Address do
  @enforce_keys [:streetname, :streenumber, :postcode, :town]
  defstruct [:streetname, :streenumber, :postcode, :town]

  @type t :: %__MODULE__{
    streetname: String.t(),
    streenumber: String.t(),
    postcode: String.t(),
    town: String.t()
  }
end

DataSpecs.load(%{
  "name" => "Joe",
  "surname" => "Smith",
  "gender" => "male",
  "address" => [%{
    "streetname" => "High Street",
    "streenumber" => "3a",
    "postcode" => "SO31 4NG",
    "town" => "Hedge End, Southampton"
  }]
}, {Person, :t})

# +> %Person{
#      address: [
#        %Address{
#          postcode: "SO31 4NG",
#          streenumber: "3a",
#          streetname: "High Street",
#          town: "Hedge End, Southampton"
#        }
#      ],
#      gender: :male,
#      name: "Joe",
#      surname: "Smith"
#    }
```

DataSpecs tries to figure out how to translate its input to a typespec.

Scalar types (such as booleans, integers, etc.) and some composite types (such as lists, plain maps), can be simply mapped one to one after validation without any additional transformation. 

However, not all Elixir types have natural representations in JSON-like data, for example dates, or don't want to expose their internals (opaque types).

Refer to the library test suite for more examples.

## Installation

```elixir
def deps do
  [
    {:dataspecs, "~> xxx"}
  ]
end
```

Typespecs should be included in the compiled ebin.

Set the `:strip_beams` option to `false` when compiling your project with mix release or mix escript.

```elixir
def project do
  [
    app: :my_app,
    deps: deps(),
    releases: [
      my_app: [strip_beams: false]
    ],
    ...
  ]
end

def project do
  [
    app: :my_script,
    deps: deps(),
    escript: [
      strip_beams: false,
      ...
    ],
    ...
  ]
end
```

## Custom type loaders

In these cases you can pass a set of custom type loaders along as an optional argument
to the `DataSpecs.load` function

```elixir
defmodule LogRow do
  @enforce_keys [:log, :timestamp]
  defstruct [:log, :timestamp]

  type t :: %__MODULE__{
    log: String.t(),
    timestamp: DateTime.t()
  }
end

def custom_isodatetime_loader(value, _custom_type_loaders, []) do
  with {:is_binary, true} <- {:is_binary, is_binary(value)},
        {:from_iso8601, {:ok, datetime, _}} <- {:from_iso8601, DateTime.from_iso8601(value)} do
    {:ok, datetime}
  else
    {:is_binary, false} ->
      {:error, ["can't convert #{inspect(value)} to a DateTime.t/0"]}

    {:from_iso8601, {:error, reason}} ->
      {:error, ["can't convert #{inspect(value)} to a DateTime.t/0 (#{inspect(reason)})"]}
  end
end

DataSpecs.load(
  %{"log" => "An error occurred", "timestamp" => "2021-07-14 20:22:49.653077Z"},
  %{{DateTime, :t, 0} => &custom_isodatetime_loader/3}
)

# => %LogRow{
#      log: "An error occurred",
#      timestamp: ~U[2021-07-14 20:22:49.653077Z]
#    }
```

The type of the custom loader function is

```elixir
(value(), custom_type_loaders(), [type_params_loader()] -> value())
```

for example a custom `MapSet.t/1` loader could be implement as:

```elixir
def custom_mapset_loader(value, custom_type_loaders, [type_params_loader]) do
  case Enumerable.impl_for(value) do
    nil ->
      {:error, ["can't convert #{inspect(value)} to a MapSet.t/1, value not enumerable"]}

    _ ->
      value
      |> Enum.to_list()
      |> Loaders.list(custom_type_loaders, [type_params_loader])
      |> case do
        {:ok, loaded_value} ->
          {:ok, MapSet.new(loaded_value)}

        {:error, errors} ->
          {:error, ["can't convert #{inspect(value)} to a MapSet.t/1", errors]}
      end
  end
end
```

The custom loader take the input value, check it's enumerable and then builds a `MapSet`
over the items of the input value. It takes as argument a list of `type_params_loader()` associated
with the type parameters.

For example, let's say we have:

```elixir
@type my_set_of_integer :: MapSet.t(integer())
```

and an input value:


```elixir
1..10
```

then the custom type loader function will be called with

```elixir
custom_mapset_loader(1..10, custom_type_loaders, [&builtin_integer_loader/3])
```

## Validators

Custom validation rules can be defined with a custom type loader.

For example let's say than we want to validate a field of type string to be in upcase form:

```elixir
defmodule AStruct do
  @enforce_keys [:field]
  defstruct [:field]

  @type t :: %__MODULE__{
    field: field()
  }

  @type field :: String.t()

  def custom_field_loader(value, custom_type_loaders, type_params_loaders) do
    name = DataSpecs.Loaders.binary(value, custom_type_loaders, type_params_loaders)

    if name == String.upcase(name) do
      {:ok, name}
    else
      {:error, ["#{inspect(value)} is not an upcase string"]}
    end
  end
end

DataSpecs.load(%{field: "AAA"}, {AStruct, :t}, %{{AStruct, :field, 0} => &AStruct.custom_field_loader/3})
# => %AStruct{field: "AAA"}
```

## Type coercion

The following types coercion are implicitly applied:

### float()

`integer() -> float()`

Example:

```elixir
# ---
1
# to
1.0
```

### tuple()

`list() -> tuple()`

```elixir
@type t :: {atom(), integer()}

# ---
[:a, 1]
# to
{:a, 1}
```

### struct()

`map() -> struct()`

Example:

```elixir
defmodule AStruct do
  defstruct [:field]

  @type t :: %__MODULE__{
    a: nil | binary(),
    b: nil | binary()
  }

# ---
%{a: "1", b: "2"}
# to
%AStruct{a: "1", b: "2"}
```

### map / struct keys

`map / struct binary() keys -> existing atom()`

Example:

```elixir

@type a_map :: %{
        a: binary,
        b: binary
      }

# ---
%{"a" => "1", "b" => "2"}
# to
%{a: "1", b: "2"}
```

### atom()

`binary() -> existing atom()`

Example:

```elixir
# ---
"bin"
# to
:bin
```