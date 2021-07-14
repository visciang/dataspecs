defmodule DataSpec do
  alias DataSpec.{Error, Typespecs}

  @type data() :: any()
  @type type_ref :: {module(), atom()}
  @type type_params_loader :: (data(), [type_params_loader()] -> data())

  @spec load(data(), type_ref(), [type_params_loader()]) :: {:error, any()} | {:ok, data()}
  def load(data, {module, type}, type_params_loaders \\ []) do
    {:ok, load!(data, {module, type}, type_params_loaders)}
  rescue
    err in Error -> {:error, err}
  end

  @spec load!(data(), type_ref(), [type_params_loader()]) :: data()
  def load!(data, {module, type}, type_params_loaders \\ []) do
    loader = Typespecs.loader(module, type, length(type_params_loaders))
    loader.(data, type_params_loaders)
  end
end
