# dataspecs

![CI](https://github.com/visciang/dataspecs/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/visciang/dataspecs/badge.svg?branch=main)](https://coveralls.io/github/visciang/dataspecs?branch=main)

Typespec based data loader and validator (inspired by [forma](https://github.com/soundtrackyourbrand/forma)).

DataSpecs **validate and load** elixir data into a more structured form
by trying to map it to conform to a [typespec](https://hexdocs.pm/elixir/typespecs.html).

It support the following typespec specifications:
- basic types
- literal types
- built-in types
- union types
- parametrized types
- map (and elixir struct) types
- remote types
- user defined types

The main use cases are about elixir data validatation against a typespec or
interfacing with external data sources that provide you data as JSON or MessagePack,
but that you wish to validate and transform into either proper structs or
richer data types without a native JSON representation (such as dates or sets).

## Usage

Given the following `Person` struct specification

```elixir
defmodule Person do
  use DataSpecs

  @enforce_keys [:name, :surname]
  defstruct @enforce_keys ++ [:gender, :address, :birth_date]

  @type t :: %__MODULE__{
               name: String.t(),
               surname: String.t(),
               gender: option(:male | :female | :other),
               address: option([Address.t(), ...]),
               birth_date: option(Date.t())
             }

  @type option(x) :: nil | x
end

defmodule Address do
  @enforce_keys [:streetname, :streenumber, :postcode, :town]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
               streetname: String.t(),
               streenumber: String.t(),
               postcode: String.t(),
               town: String.t()
             }
end
```

we can load a JSON object encoding an instance of a `Person` with:

```elixir
~s/{
  "name": "Joe",
  "surname": "Smith",
  "gender": "male",
  "birth_date": "1980-12-31",
  "address": [{
    "streetname": "High Street",
    "streenumber": "3a",
    "postcode": "SO31 4NG",
    "town": "Hedge End, Southampton"
  }]
}/
|> Jason.decode!()
|> Person.load(DataSpecs.Loader.Extra.type_loaders())

# NOTE:
# DataSpecs.Loader.Extra.type_loaders() is included here to support
# the loading of isodates strings into Date.t() types.
# Ref: "Type loaders" section

# => %Person{
#      address: [
#        %Address{
#          postcode: "SO31 4NG",
#          streenumber: "3a",
#          streetname: "High Street",
#          town: "Hedge End, Southampton"
#        }
#      ],
#      birth_date: ~D[1980-12-31],
#      gender: :male,
#      name: "Joe",
#      surname: "Smith"
#    }
```

DataSpecs tries to figure out how to translate its input to an elixir datatype using the typespec as "type schema".

Scalar types (such as booleans, integers, etc.) and some composite types
(such as lists, plain maps), can be simply mapped one to one after validation
without any additional transformation. 

However, not all Elixir types have natural representations in JSON-like data,
for example atoms, dates, or don't want to expose their internals (opaque types).

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

Set the `:strip_beams` option to `false` when compiling your project with mix
release or mix escript.

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

## Type loaders

### Builtin

For reference check the loaders available under `DataSpecs.Loader.{Builtin, Extra}`.

The modules `DataSpecs.Loader.Extra` provides pre defined custom type loader for:
- `DateTime.t`: load iso datetime strings (ie: `2001-12-31 06:54:02Z` -> `~U[2001-12-31 06:54:02Z]`)
- `DateTime.t`: load iso datetime strings (ie: `2001-12-31` -> `~D[2022-06-03]`)
- `MapSet.t`: load lists of T into a `MapSet.t(T)` (ie: `[1, 2]` -> `#MapSet<[1, 2]>`)

### Custom

You can pass custom type loaders along as an optional argument to the `DataSpecs.load` function.
```

The type of the custom loader function is

```elixir
(value(), custom_type_loaders(), [type_loader_fun()] -> value())
```

for example a custom `MapSet.t/1` loader could be implement as:

```elixir
def custom_mapset_loader(value, custom_type_loaders, [type_loader_fun]) do
  case Enumerable.impl_for(value) do
    nil ->
      {:error, ["can't convert #{inspect(value)} to a MapSet.t/1, value not enumerable"]}

    _ ->
      value
      |> Enum.to_list()
      |> DataSpecs.Loader.Builtin.list(custom_type_loaders, [type_loader_fun])
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
over the items of the input value. It takes as argument a list of `type_loader_fun()` associated
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
custom_mapset_loader(1..10, custom_type_loaders, [&DataSpecs.Loader.Builtin.integer/3])
```

## Validators

Custom validation rules can be defined with a custom type loader.

For example let's say than we want to validate a field of type string to be in upcase form:

```elixir
defmodule AStruct do
  use DataSpecs

  @enforce_keys [:field]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
               field: upcase_string()
             }

  @type upcase_string :: String.t()

  def custom_field_loader(value, custom_type_loaders, type_params_loaders) do
    with {:ok, value} <- DataSpecs.Loader.Builtin.binary(value, custom_type_loaders, type_params_loaders)
         ^name <- String.upcase(name) do
      {:ok, name}
    else
      {:error, errors} ->
        {:error, ["#{inspect(value)} is not an upcase string", errors]}

      false ->
        {:error, ["#{inspect(value)} is not an upcase string"]}
    end
  end
end

custom_type_loaders = %{{AStruct, :upcase_string, 0} => &AStruct.custom_field_loader/3}
AStruct.load(%{field: "AAA"}, custom_type_loaders)
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
  defstruct [:a, :b]

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

## Plug

`DataSpecs.Plug.Loader` provides a plug to "Jason.decode! -> DataSpecs.load" in your routes:

```elixir
defmodule Api.Router.Something do
  use Plug.Router
  import DataSpecs.Plug.Loader, only: [typeref: 2, value: 1]

  plug :match
  plug DataSpecs.Plug.Loader
  plug :dispatch

  post "/foo", typeref(Api.Model.Foo, :t) do
    %Api.Model.Foo{...} = value(conn)
    ...
  end
end
```

## Ecto embedded schema validation comparison

https://github.com/visciang/example_validation
