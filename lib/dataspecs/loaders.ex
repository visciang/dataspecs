defmodule DataSpecs.Loaders do
  @moduledoc false

  def any(value, _custom_type_loaders, _type_params_loaders) do
    {:ok, value}
  end

  def atom(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_atom(value) ->
        {:ok, value}

      value when is_binary(value) ->
        try do
          {:ok, String.to_existing_atom(value)}
        rescue
          ArgumentError ->
            {:error, ["can't convert #{inspect(value)} to an existing atom"]}
        end

      _ ->
        {:error, ["can't convert #{inspect(value)} to an atom"]}
    end
  end

  def boolean(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_boolean(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a boolean"]}
    end
  end

  def binary(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_binary(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a binary"]}
    end
  end

  def pid(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_pid(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a pid"]}
    end
  end

  def reference(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_reference(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a reference"]}
    end
  end

  def number(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_number(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a number"]}
    end
  end

  def float(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_number(value) ->
        {:ok, :erlang.float(value)}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a float"]}
    end
  end

  def integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to an integer"]}
    end
  end

  def neg_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value < 0 ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a neg_integer"]}
    end
  end

  def non_neg_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value >= 0 ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a non_neg_integer"]}
    end
  end

  def pos_integer(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and value > 0 ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a pos_integer"]}
    end
  end

  def range(lower, upper, value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_integer(value) and lower <= value and value <= upper ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a range #{inspect(lower..upper)}"]}
    end
  end

  def union(value, custom_type_loaders, type_params_loaders) do
    type_params_loaders
    |> Enum.reduce_while({:error, []}, fn loader, {:error, errors} ->
      loader.(value, custom_type_loaders, [])
      |> case do
        {:ok, res} ->
          {:halt, {:ok, res}}

        {:error, new_errors} ->
          {:cont, {:error, errors ++ new_errors}}
      end
    end)
    |> case do
      {:ok, res} ->
        {:ok, res}

      {:error, errors} ->
        {:error, ["can't convert #{inspect(value)} to a union", errors]}
    end
  end

  def empty_list(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      [] ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to an empty list"]}
    end
  end

  def nonempty_list(value, custom_type_loaders, type_params_loaders) do
    case value do
      [_ | _] ->
        list(value, custom_type_loaders, type_params_loaders)

      _ ->
        {:error, ["can't convert #{inspect(value)} to a non empty list"]}
    end
  end

  def list(value, custom_type_loaders, type_params_loaders) do
    case value do
      value when is_list(value) ->
        load_list(value, custom_type_loaders, type_params_loaders)

      _ ->
        {:error, ["can't convert #{inspect(value)} to a list"]}
    end
  end

  defp load_list(value, _custom_type_loaders, []) do
    # case for:  list() -> list(any())
    {:ok, value}
  end

  defp load_list(value, custom_type_loaders, [type_params_loader]) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, item_idx}, loaded_list ->
      type_params_loader.(item, custom_type_loaders, [])
      |> case do
        {:ok, loaded_value} ->
          {:cont, [loaded_value | loaded_list]}

        {:error, errors} ->
          error = "can't convert #{inspect(value)} to a list, bad item at index=#{item_idx}"
          {:halt, {:error, [error, errors]}}
      end
    end)
    |> case do
      {:error, _} = error ->
        error

      loaded_list ->
        {:ok, Enum.reverse(loaded_list)}
    end
  end

  def empty_map(value, _custom_type_loaders, []) do
    if value == %{} do
      {:ok, value}
    else
      {:error, ["can't convert #{inspect(value)} to an empty map"]}
    end
  end

  def map_field_required(map, custom_type_loaders, [type_key_loader, type_value_loader]) do
    map_field_optional(map, custom_type_loaders, [type_key_loader, type_value_loader])
    |> case do
      {:ok, {_map_rest, map_processed, errors}} when map_size(map_processed) == 0 ->
        {:error, ["can't convert #{inspect(map)} to a map, missing required k/v", errors]}

      {:ok, res} ->
        {:ok, res}

      {:error, errors} ->
        {:error, errors}
    end
  end

  def map_field_optional(map, custom_type_loaders, [type_key_loader, type_value_loader]) do
    case map do
      map when is_struct(map) ->
        map = Map.from_struct(map)
        map_field_optional(map, custom_type_loaders, [type_key_loader, type_value_loader])

      map when is_map(map) ->
        res =
          Enum.reduce(map, {map, %{}, []}, fn {map_key, map_value}, {map_rest, map_processed, errors} ->
            with {:ok, map_key_processed} <- type_key_loader.(map_key, custom_type_loaders, []),
                 {:ok, map_value_processed} <- type_value_loader.(map_value, custom_type_loaders, []) do
              map_processed = Map.put(map_processed, map_key_processed, map_value_processed)
              map_rest = Map.delete(map_rest, map_key)

              {map_rest, map_processed, errors}
            else
              {:error, new_errors} ->
                {map_rest, map_processed, errors ++ new_errors}
            end
          end)

        {:ok, res}

      _ ->
        {:error, ["can't convert #{inspect(map)} to a map"]}
    end
  end

  @spec tuple_any(any, any, any) :: {:error, [<<_::64, _::_*8>>, ...]} | {:ok, tuple}
  def tuple_any(value, _custom_type_loaders, _type_params_loaders) do
    case value do
      value when is_tuple(value) ->
        {:ok, value}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a tuple"]}
    end
  end

  def tuple(value, custom_type_loaders, type_params_loaders) do
    tuple_type_size = length(type_params_loaders)

    case value do
      value when is_tuple(value) and tuple_size(value) == tuple_type_size ->
        load_tuple(value, custom_type_loaders, type_params_loaders)

      value when is_list(value) and length(value) == tuple_type_size ->
        tuple(List.to_tuple(value), custom_type_loaders, type_params_loaders)

      value when is_tuple(value) or is_list(value) ->
        {:error, ["can't convert #{inspect(value)} to a tuple of size #{tuple_type_size}"]}

      _ ->
        {:error, ["can't convert #{inspect(value)} to a tuple"]}
    end
  end

  defp load_tuple(value, custom_type_loaders, type_params_loaders) do
    value
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.zip(type_params_loaders)
    |> Enum.reduce_while([], fn {{item, item_idx}, loader}, loaded_list ->
      loader.(item, custom_type_loaders, [])
      |> case do
        {:ok, loaded_value} ->
          {:cont, [loaded_value | loaded_list]}

        {:error, errors} ->
          error = "can't convert #{inspect(value)} to a tuple, bad item at index=#{item_idx}"
          {:halt, {:error, [error, errors]}}
      end
    end)
    |> case do
      {:error, _} = error ->
        error

      loaded_list ->
        loaded_tuple =
          loaded_list
          |> Enum.reverse()
          |> List.to_tuple()

        {:ok, loaded_tuple}
    end
  end
end
