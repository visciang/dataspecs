defmodule DataSpec do
  alias DataSpec.{Error, Typespecs}

  def load(data, {module, type}, type_params \\ []) do
    {:ok, load!(data, {module, type}, type_params)}
  rescue
    err in Error -> {:error, err}
  end

  def load!(data, {module, type}, type_params \\ []) do
    parser = Typespecs.loader(module, type, length(type_params))
    parser.(data, type_params)
  end
end
