defmodule DataSpec do
  @moduledoc File.read!("README.md")

  use Application
  alias DataSpec.{Error, Typespecs}

  @type value() :: any()
  @type type_id :: atom()
  @type type_ref :: {module(), type_id()}
  @type custom_type_ref :: {module(), type_id(), arity()}
  @type type_params_loader :: (value(), custom_type_loaders(), [type_params_loader] -> value())
  @type custom_type_loaders :: %{custom_type_ref() => type_params_loader()}

  @spec load(value(), type_ref(), custom_type_loaders(), [type_params_loader()]) :: {:error, any()} | {:ok, value()}
  def load(value, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    {:ok, load!(value, {module, type_id}, custom_type_loaders, type_params_loaders)}
  rescue
    error in Error ->
      {:error, error}
  end

  @spec load!(value(), type_ref(), custom_type_loaders(), [type_params_loader()]) :: value()
  def load!(value, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    loader = Typespecs.loader(module, type_id, length(type_params_loaders))
    loader.(value, custom_type_loaders, type_params_loaders)
  end

  def start(_type, _args) do
    Supervisor.start_link([DataSpec.Cache], strategy: :one_for_one)
  end
end
