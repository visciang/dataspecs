# dataspec

![CI](https://github.com/visciang/dataspec/workflows/CI/badge.svg) [![Coverage Status](https://coveralls.io/repos/github/visciang/dataspec/badge.svg?branch=master)](https://coveralls.io/github/visciang/dataspec?branch=master)

Typespec based data loader (and validator) for Elixir.

DataSpec can validate and load elixir data into a more structured form
by trying to map it to conform to a typespec.

It can be simply used to validate some elixir data against a typespec or it
can be useful when interfacing with external data sources that provide
you data as JSON or MessagePack, but that you wish to transform into either
proper structs or richer data types without a native JSON representation
(such as dates or sets) in your application.

```elixir
defmodule User do
  defstruct [:id, :name, :age, :gender]

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    age: non_neg_integer(),
    gender: :male | :female | :other | :prefer_not_to_say
  }
end

DataSpec.load!(%{"id" => "1", "name" => "Fredrik", "age" => 30, "gender" => :male}, {User, :t})
# => %User{id: "1", name: "Fredrik", age: 30, gender: :male}
```

DataSpec tries to figure out how to translate its input to a typespec.
Some types can be simply mapped one to one, all the scalar types such as
booleans, integers, etc. and some composite types such as lists, plain maps.

However, not all types have natural representations in JSON, for example dates,
or don't want to expose their internals (opaque types).

In these cases you can pass a set of custom type loaders along as an optional argument
to the DataSpec.load function

```elixir
defmodule LogRow do
  defstruct [:log, :timestamp]

  type t :: %__MODULE__{
    log: String.t(),
    timestamp: DateTime.t()
  }
end

def custom_isodatetime_loader(value, _custom_type_loaders, []) do
  with {:is_binary, true} <- {:is_binary, is_binary(value)},
        {:from_iso8601, {:ok, datetime, _}} <- {:from_iso8601, DateTime.from_iso8601(value)} do
    datetime
  else
    {:is_binary, false} ->
      raise DataSpec.Error, "can't convert #{inspect(value)} to a DateTime.t/0"

    {:from_iso8601, {:error, reason}} ->
      raise DataSpec.Error, "can't convert #{inspect(value)} to a DateTime.t/0 (#{inspect(reason)})"
  end
end

DataSpec.load!(
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
(value(), custom_type_loaders(), [type_params_loader] -> value())
```

for example a custom `MapSet.t/1` loader could be implement as:

```elixir
def custom_mapset_loader(value, custom_type_loaders, [type_params_loader] do
  case Enumerable.impl_for(value) do
    nil ->
      raise DataSpec.Error, "can't convert #{inspect(value)} to a MapSet.t/1"

    _ ->
      MapSet.new(value, &type_params_loader.(&1, custom_type_loaders, []))
  end
end
```

The custom loader take the input value, check it's enumerable and then builds a `MapSet`
over the items of the input value.
Like every loader it takes, as the last argument, a list of type_params_loader associated
with the type parameters (in this case an `integer()` loader since we have a `MapSet.t(integer())`)

For example, let's say we have:

```elixir
@type my_set_of_integer :: MapSet.t(integer())
```

and the input value:


```elixir
1..10
```

then the custom type loader function will be called with

```elixir
custom_mapset_loader(1..10, custom_type_loaders, [&builtin_integer_loader/3])
```

Refer to the library test suite for more examples.
