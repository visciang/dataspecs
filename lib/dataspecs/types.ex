defmodule DataSpecs.Types do
  @moduledoc """
  Common types
  """

  @type value() :: any()
  @type reason :: [String.t() | reason()]
  @type type_id :: atom()
  @type type_ref :: {module(), type_id()}
  @type custom_type_ref :: {module(), type_id(), arity()}
  @type type_loader_fun :: (value(), custom_type_loaders(), [type_loader_fun] -> value())
  @type custom_type_loaders :: %{custom_type_ref() => type_loader_fun()}
  @type load_result(t) :: {:error, reason()} | {:ok, t}
end
