defmodule DataSpec do
  use Application
  alias DataSpec.{Error, Typespecs}

  @type data() :: any()
  @type type_id :: atom()
  @type type_ref :: {module(), type_id()}
  @type custom_type_ref :: {module(), type_id(), arity()}
  @type type_params_loader :: (data(), [type_params_loader()] -> data())
  @type custom_type_loaders :: %{custom_type_ref() => type_params_loader()}

  @spec load(data(), type_ref(), custom_type_loaders(), [type_params_loader()]) :: {:error, any()} | {:ok, data()}
  def load(data, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    {:ok, load!(data, {module, type_id}, custom_type_loaders, type_params_loaders)}
  rescue
    err in Error -> {:error, err}
  end

  @spec load!(data(), type_ref(), custom_type_loaders(), [type_params_loader()]) :: data()
  def load!(data, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    loader = Typespecs.loader(module, type_id, length(type_params_loaders))
    loader.(data, custom_type_loaders, type_params_loaders)
  end

  def start(_type, _args) do
    Supervisor.start_link([DataSpec.Cache], strategy: :one_for_one)
  end
end
