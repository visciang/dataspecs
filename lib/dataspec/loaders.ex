defmodule DataSpec.Loaders do
  @moduledoc false

  alias DataSpec.Error

  def any(value, _custom_type_loaders, _type_params_loaders) do
    value
  end

  def atom(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_atom(value) ->
        value

      value when is_binary(value) ->
        try do
          String.to_existing_atom(value)
        rescue
          ArgumentError ->
            reraise Error, [message: "can't convert #{inspect(value)} to an existing atom"], __STACKTRACE__
        end

      _ ->
        raise Error, "can't convert #{inspect(value)} to an atom"
    end
  end

  def boolean(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_boolean(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a boolean"
    end
  end

  def binary(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_binary(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a binary"
    end
  end

  def pid(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_pid(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a pid"
    end
  end

  def reference(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_reference(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a reference"
    end
  end

  def number(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_number(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a number"
    end
  end

  def float(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_number(value) ->
        :erlang.float(value)

      _ ->
        raise Error, "can't convert #{inspect(value)} to a float"
    end
  end

  def integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to an integer"
    end
  end

  def neg_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value < 0 ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a neg_integer"
    end
  end

  def non_neg_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value >= 0 ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a non_neg_integer"
    end
  end

  def pos_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value > 0 ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a pos_integer"
    end
  end

  def range(lower, upper, value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and lower <= value and value <= upper ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a range #{inspect(lower..upper)}"
    end
  end

  def union(value, custom_type_loaders, type_params_loaders) do
    type_params_loaders
    |> Enum.reduce_while(:error, fn loader, _ ->
      try do
        {:halt, {:ok, loader.(value, custom_type_loaders, [])}}
      rescue
        Error ->
          {:cont, :error}
      end
    end)
    |> case do
      {:ok, res} ->
        res

      :error ->
        raise Error, "can't convert #{inspect(value)} to a union"
    end
  end

  def empty_list(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      [] ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to an empty list"
    end
  end

  def nonempty_list(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      [_ | _] ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a non empty list"
    end
  end

  def list(value, _custom_type_loaders, []) do
    case value do
      value when is_list(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a list"
    end
  end

  def list(value, custom_type_loaders, [type_params_loader]) do
    case value do
      value when is_list(value) ->
        Enum.map(value, &type_params_loader.(&1, custom_type_loaders, []))

      _ ->
        raise Error, "can't convert #{inspect(value)} to a list"
    end
  end

  def empty_map(value, _custom_type_loaders, []) do
    if value == %{} do
      value
    else
      raise Error, "can't convert #{inspect(value)} to an empty map"
    end
  end

  def map_field_required(map, custom_type_loaders, [type_key_loader, type_value_loader]) do
    {map_rest, map_processed} = map_field_optional(map, custom_type_loaders, [type_key_loader, type_value_loader])

    if map_size(map_processed) == 0 do
      raise Error, "can't convert #{inspect(map)} to a map, missing required k/v"
    end

    {map_rest, map_processed}
  end

  def map_field_optional(map, custom_type_loaders, [type_key_loader, type_value_loader]) do
    case map do
      map when is_map(map) ->
        Enum.reduce(map, {map, %{}}, fn {map_key, map_value}, {map_rest, map_processed} ->
          try do
            map_key_processed = type_key_loader.(map_key, custom_type_loaders, [])
            map_value_processed = type_value_loader.(map_value, custom_type_loaders, [])
            map_processed = Map.put(map_processed, map_key_processed, map_value_processed)

            map_rest = Map.delete(map_rest, map_key)

            {map_rest, map_processed}
          rescue
            Error ->
              {map_rest, map_processed}
          end
        end)

      _ ->
        raise Error, "can't convert #{inspect(map)} to a map"
    end
  end

  def tuple_any(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_tuple(value) ->
        value

      _ ->
        raise Error, "can't convert #{inspect(value)} to a tuple"
    end
  end

  def tuple(value, custom_type_loaders, type_params_loaders) do
    tuple_type_size = length(type_params_loaders)

    cond do
      is_tuple(value) and tuple_size(value) == tuple_type_size ->
        value
        |> Tuple.to_list()
        |> Enum.zip(type_params_loaders)
        |> Enum.map(fn {item, loader} -> loader.(item, custom_type_loaders, []) end)
        |> List.to_tuple()

      is_tuple(value) ->
        raise Error, "can't convert #{inspect(value)} to a tuple of size #{tuple_type_size}"

      true ->
        raise Error, "can't convert #{inspect(value)} to a tuple"
    end
  end
end
