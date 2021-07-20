defmodule DataSpec.Error do
  @moduledoc false

  defexception [:errors]

  @type errors :: [String.t() | errors()]

  @type t :: %__MODULE__{
          errors: errors()
        }

  # coveralls-ignore-start

  @impl Exception
  def message(%__MODULE__{errors: errors}) do
    inspect(errors)
  end

  # coveralls-ignore-end
end
