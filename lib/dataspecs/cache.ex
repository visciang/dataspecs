defmodule DataSpecs.Cache do
  @moduledoc false

  use GenServer
  alias DataSpecs.Types

  @name __MODULE__
  @ets_name __MODULE__

  @type cache_key :: Types.mta()
  @type cache_value :: Types.type_cast_fun()

  @spec get(module(), Types.type_id(), arity()) :: nil | cache_value()
  def get(module, type_id, type_arity) do
    type_ref = {module, type_id, type_arity}

    case :ets.lookup(@ets_name, type_ref) do
      [] ->
        nil

      [{^type_ref, type_cast}] ->
        type_cast
    end
  end

  @spec set([{cache_key(), cache_value()}]) :: :ok
  def set(type_casts) do
    GenServer.call(@name, {:set, type_casts}, :infinity)
    :ok
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(@name, nil, name: @name)
  end

  @impl GenServer
  def init(nil) do
    :ets.new(@ets_name, [:set, :protected, :named_table, read_concurrency: true])
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:set, type_casts}, _from, state) do
    :ets.insert(@ets_name, type_casts)
    {:reply, :ok, state}
  end
end
