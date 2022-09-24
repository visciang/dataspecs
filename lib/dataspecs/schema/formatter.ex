defmodule DataSpecs.Schema.Formatter do
  @moduledoc """
  Formatter.
  """

  alias DataSpecs.Schema.Quoted
  alias DataSpecs.Schema.Type

  @doc """
  Covert a schema to its typespec representation.
  """
  @spec to_typespec_string(Type.t(), width :: pos_integer()) :: String.t()
  def to_typespec_string(%Type{} = t, width \\ 80) do
    t
    |> Quoted.from_schema()
    |> Code.quoted_to_algebra()
    |> Inspect.Algebra.format(width)
    |> IO.iodata_to_binary()
  end
end
