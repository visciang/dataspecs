defmodule DataSpec.Error do
  @moduledoc false

  defexception [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }
end
