defmodule DataSpec.Types do
  alias DataSpec.Error

  def literal(literal, value, _) do
    case value do
      ^literal -> value
      _ -> raise Error, "can't convert #{inspect(value)} to literal #{inspect(literal)}"
    end
  end

  def any(value, _) do
    value
  end

  def atom(value, _) do
    case value do
      value when is_atom(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to an atom"
    end
  end

  def boolean(value, _) do
    case value do
      value when is_boolean(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a boolean"
    end
  end

  def binary(value, _) do
    case value do
      value when is_binary(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a binary"
    end
  end

  def pid(value, _) do
    case value do
      value when is_pid(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a pid"
    end
  end

  def reference(value, _) do
    case value do
      value when is_reference(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a reference"
    end
  end

  def number(value, _) do
    case value do
      value when is_number(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a number"
    end
  end

  def float(value, _) do
    case value do
      value when is_number(value) -> :erlang.float(value)
      _ -> raise Error, "can't convert #{inspect(value)} to a float"
    end
  end

  def integer(value, _) do
    case value do
      value when is_integer(value) -> value
      _ -> raise Error, "can't convert #{inspect(value)} to an integer"
    end
  end

  def neg_integer(value, _) do
    case value do
      value when is_integer(value) and value < 0 -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a neg_integer"
    end
  end

  def non_neg_integer(value, _) do
    case value do
      value when is_integer(value) and value >= 0 -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a non_neg_integer"
    end
  end

  def pos_integer(value, _) do
    case value do
      value when is_integer(value) and value > 0 -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a pos_integer"
    end
  end

  def range(lower, upper, value, _) do
    case value do
      value when is_integer(value) and lower <= value and value <= upper -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a range of #{inspect(lower..upper)}"
    end
  end

  def union(value, type_params_processors) do
    type_params_processors
    |> Enum.reduce_while(:error, fn processor, _ ->
      try do
        {:halt, {:ok, processor.(value, [])}}
      rescue
        Error ->
          {:cont, :error}
      end
    end)
    |> case do
      {:ok, res} -> res
      :error -> raise Error, "can't convert #{inspect(value)} to a union"
    end
  end

  def empty_list(value, _type_params_processors) do
    case value do
      [] -> value
      _ -> raise Error, "can't convert #{inspect(value)} to an empty list"
    end
  end

  def nonempty_list(value, _type_params_processors) do
    case value do
      [_ | _] -> value
      _ -> raise Error, "can't convert #{inspect(value)} to a non empty list"
    end
  end

  def list(value, [type_params_processor]) do
    case value do
      value when is_list(value) -> Enum.map(value, &type_params_processor.(&1, []))
      _ -> raise Error, "can't convert #{inspect(value)} to a list"
    end
  end

  def empty_map(value, []) do
    if value == %{} do
      value
    else
      raise Error, "can't convert #{inspect(value)} to an empty map"
    end
  end

  def map_field_required(map, [type_key_processor, type_value_processor]) do
    {map_rest, map_processed} = map_field_optional(map, [type_key_processor, type_value_processor])

    if map_size(map_processed) == 0 do
      raise Error, "can't convert #{inspect(map)} to a map, missing required k/v"
    end

    {map_rest, map_processed}
  end

  def map_field_optional(map, [type_key_processor, type_value_processor]) do
    case map do
      map when is_map(map) ->
        Enum.reduce(map, {map, %{}}, fn {map_key, map_value}, {map_rest, map_processed} ->
          try do
            map_key_processed = type_key_processor.(map_key, [])
            map_value_processed = type_value_processor.(map_value, [])
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

  def tuple(value, type_params_processors) do
    case value do
      value when is_tuple(value) ->
        value
        |> Tuple.to_list()
        |> Enum.zip(type_params_processors)
        |> Enum.map(fn {item, processor} -> processor.(item, []) end)
        |> List.to_tuple()

      _ ->
        raise Error, "can't convert #{inspect(value)} to a tuple"
    end
  end
end
