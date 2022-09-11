defmodule DataSpecs.Schema.Anonymous do
  @moduledoc false

  alias DataSpecs.Schema.Type

  @spec build(module(), Type.type()) :: Type.t()
  def build(module, type) do
    %Type{
      visibility: :typep,
      module: module,
      id: nil,
      vars: extract_vars(type),
      type: type
    }
  end

  @spec extract_vars(Type.type()) :: [Type.Var.t()]
  defp extract_vars(%Type.Literal.Atom{}), do: []
  defp extract_vars(%Type.Literal.Integer{}), do: []
  defp extract_vars(%Type.Builtin{}), do: []
  defp extract_vars(%Type.Bitstring{}), do: []
  defp extract_vars(%Type.Range{}), do: []
  defp extract_vars(%Type.Unsupported{}), do: []
  defp extract_vars(%Type.Var{} = var), do: [var]
  defp extract_vars(%Type.List{of: type}), do: extract_vars(type)
  defp extract_vars(%Type.Union{of: types}), do: Enum.flat_map(types, &extract_vars/1) |> Enum.uniq()
  defp extract_vars(%Type.Tuple{of: types}), do: Enum.flat_map(types, &extract_vars/1) |> Enum.uniq()
  defp extract_vars(%Type.Ref{params: params}), do: Enum.flat_map(params, &extract_vars/1) |> Enum.uniq()

  defp extract_vars(%Type.Map{of: kv}) do
    kv
    |> Enum.flat_map(fn {%Type.Map.Key{type: ktype}, vtype} ->
      [extract_vars(ktype), extract_vars(vtype)]
    end)
    |> List.flatten()
    |> Enum.uniq()
  end
end
