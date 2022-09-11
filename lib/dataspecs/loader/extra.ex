defmodule DataSpecs.Loader.Extra do
  @moduledoc """
  Elixir types loaders
  """

  alias DataSpecs.{Loader, Types}

  @doc """
  All extra type loaders.

  MyData.load(value, #{inspect(__MODULE__)}.type_loaders())
  """
  @spec type_loaders() :: Types.custom_type_loaders()
  def type_loaders do
    %{
      {MapSet, :t, 1} => &mapset/3,
      {DateTime, :t, 0} => &isodatetime/3,
      {Date, :t, 0} => &isodate/3
    }
  end

  @doc """
  Type loader for Elixir MapSet.t(T).
  Expect an Enumarable value of type T, returns a MapSet.t(T).
  """
  @spec mapset(Types.value(), Types.custom_type_loaders(), [Types.type_loader_fun()]) ::
          {:error, Types.reason()} | {:ok, MapSet.t()}
  def mapset(value, custom_type_loaders, [type_params_loader]) do
    case Enumerable.impl_for(value) do
      nil ->
        {:error, ["can't convert #{inspect(value)} to a MapSet.t/1, value not enumerable"]}

      _ ->
        value
        |> Enum.to_list()
        |> Loader.Builtin.list(custom_type_loaders, [type_params_loader])
        |> case do
          {:ok, loaded_value} ->
            {:ok, MapSet.new(loaded_value)}

          {:error, errors} ->
            {:error, ["can't convert #{inspect(value)} to a MapSet.t/1", errors]}
        end
    end
  end

  @doc """
  Type loader for Elixir DateTime.t().
  Expect an iso8601 datetime string value, returns a DateTime.t().
  """
  @spec isodatetime(Types.value(), Types.custom_type_loaders(), [Types.type_loader_fun()]) ::
          {:error, Types.reason()} | {:ok, DateTime.t()}
  def isodatetime(value, _custom_type_loaders, []) do
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

  @doc """
  Type loader for Elixir Date.t().
  Expect an iso8601 date string value, returns a Date.t().
  """
  @spec isodate(Types.value(), Types.custom_type_loaders(), [Types.type_loader_fun()]) ::
          {:error, Types.reason()} | {:ok, DateTime.t()}
  def isodate(value, _custom_type_loaders, []) do
    with {:is_binary, true} <- {:is_binary, is_binary(value)},
         {:from_iso8601, {:ok, date}} <- {:from_iso8601, Date.from_iso8601(value)} do
      {:ok, date}
    else
      {:is_binary, false} ->
        {:error, ["can't convert #{inspect(value)} to a Date.t/0"]}

      {:from_iso8601, {:error, reason}} ->
        {:error, ["can't convert #{inspect(value)} to a Date.t/0 (#{inspect(reason)})"]}
    end
  end
end
