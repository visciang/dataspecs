defmodule DataSpecs.Cache do
  @moduledoc false

  use GenServer

  @name __MODULE__
  @ets_name __MODULE__

  def get(module, type_id, type_arity) do
    type_ref = {module, type_id, type_arity}

    case :ets.lookup(@ets_name, type_ref) do
      [] ->
        nil

      [{^type_ref, type_loader}] ->
        type_loader
    end
  end

  def set(type_loaders) do
    GenServer.call(@name, {:set, type_loaders})
  end

  def start_link(_args) do
    GenServer.start_link(@name, nil, name: @name)
  end

  @impl GenServer
  def init(nil) do
    :ets.new(@ets_name, [:set, :protected, :named_table])
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:set, type_loaders}, _from, state) do
    :ets.insert(@ets_name, type_loaders)
    {:reply, :ok, state}
  end
end
