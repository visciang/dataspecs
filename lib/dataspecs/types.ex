defmodule DataSpecs.Types do
  @moduledoc """
  Common types.
  """

  @type value() :: any()
  @type reason :: [String.t() | reason()]
  @type type_id :: atom()
  @type mt :: {module(), type_id()}
  @type mta :: {module(), type_id(), arity()}
  @type type_cast_fun :: (value(), custom_type_casts(), [type_cast_fun] -> value())
  @type custom_type_casts :: %{mta() => type_cast_fun()}
  @type cast_result(t) :: {:error, reason()} | {:ok, t}
end
