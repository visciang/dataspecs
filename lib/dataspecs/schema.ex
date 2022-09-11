defmodule DataSpecs.Schema do
  @moduledoc """
  DataSpec Schema.
  """

  alias DataSpecs.Schema.Type
  require DataSpecs.Schema.Type

  @doc """
  Load all the typespec defined in `module` into `t:DataSpecs.Schema.Type.t/0` structs.
  """
  @spec load(module()) :: [Type.t()]
  def load(module) do
    module
    |> code_typespec_fetch_types()
    |> Enum.map(fn {visibility, {type_id, eatf, type_vars}} ->
      %Type{
        visibility: visibility,
        module: module,
        id: type_id,
        vars: Enum.map(type_vars, &eatf_type(module, &1)),
        type: eatf_type(module, eatf)
      }
    end)
  end

  @spec code_typespec_fetch_types(module) :: [term()]
  defp code_typespec_fetch_types(module) do
    module
    |> Code.Typespec.fetch_types()
    |> case do
      {:ok, eaf_types} ->
        eaf_types

      :error ->
        raise """
        Can't fetch type specifications for module #{inspect(module)}.

        The dataspec library works leveraging the typespec of #{inspect(module)}.
        To correctly introspec and retrieve the typespecs the module #{inspect(module)}
        should be compiled with the option strip_beams=false.
        Even more, the typespec cannot be retrieved if you define the module #{inspect(module)}
        in an interactive iex shell session.
        """
    end
  end

  @spec eatf_type(module(), term()) :: Type.type()
  defp eatf_type(module, {:type, lineno, :term, []}) do
    eatf_type(module, {:type, lineno, :any, []})
  end

  defp eatf_type(_module, {type, 0, literal})
       when type in Type.literal_types() do
    case type do
      :atom -> %Type.Literal.Atom{value: literal}
      :integer -> %Type.Literal.Integer{value: literal}
    end
  end

  defp eatf_type(_module, {:type, _lineno, builtin_type, []})
       when builtin_type in Type.zero_arity_builtin_types() do
    %Type.Builtin{id: builtin_type}
  end

  defp eatf_type(_module, {:type, _lineno, :binary, [{:integer, _, size}, {:integer, _, unit}]}) do
    %Type.Bitstring{size: size, unit: unit}
  end

  defp eatf_type(_module, {:type, _lineno, :range, [{:integer, 0, lower}, {:integer, 0, upper}]}) do
    %Type.Range{lower: lower, upper: upper}
  end

  defp eatf_type(_module, {:var, _lineno, id}) do
    %Type.Var{id: id}
  end

  defp eatf_type(module, {:type, _lineno, :union, type_params}) do
    %Type.Union{of: Enum.map(type_params, &eatf_type(module, &1))}
  end

  defp eatf_type(module, {:type, _lineno, list, type_params})
       when list in [nil, :list, :nonempty_list] do
    cardinality =
      case list do
        nil -> 0
        :list -> :*
        :nonempty_list -> :+
      end

    type_param =
      case type_params do
        [] -> {:type, 0, :any, []}
        [type_param] -> type_param
      end

    %Type.List{cardinality: cardinality, of: eatf_type(module, type_param)}
  end

  defp eatf_type(module, {:type, _lineno, :tuple, type_params}) do
    cardinality =
      case type_params do
        :any -> :*
        _ -> length(type_params)
      end

    type_params =
      case type_params do
        :any -> [{:type, 0, :any, []}]
        _ -> type_params
      end

    %Type.Tuple{cardinality: cardinality, of: Enum.map(type_params, &eatf_type(module, &1))}
  end

  defp eatf_type(module, {:type, _lineno, :map, kv_type_params}) do
    of =
      Enum.map(kv_type_params, fn
        {:type, _lineno, map_field_flavor, [key_eatf, value_eatf]}
        when map_field_flavor in [:map_field_exact, :map_field_assoc] ->
          key_type = %Type.Map.Key{
            required?: map_field_flavor == :map_field_exact,
            type: eatf_type(module, key_eatf)
          }

          value_type = eatf_type(module, value_eatf)

          {key_type, value_type}
      end)

    Enum.find(of, &match?({%Type.Map.Key{type: %Type.Literal.Atom{value: :__struct__}}, %Type.Literal.Atom{}}, &1))
    |> case do
      nil ->
        %Type.Map{struct: nil, of: of}

      {%Type.Map.Key{}, %Type.Literal.Atom{value: struct_module}} = kv_struct ->
        of = List.delete(of, kv_struct)
        %Type.Map{struct: struct_module, of: of}
    end
  end

  defp eatf_type(
         module,
         {:remote_type, _lineno, [{:atom, _, remote_module}, {:atom, _, remote_type_id}, remote_type_params]}
       ) do
    %Type.Ref{module: remote_module, id: remote_type_id, params: Enum.map(remote_type_params, &eatf_type(module, &1))}
  end

  defp eatf_type(module, {:user_type, _lineno, user_type_id, type_params}) do
    %Type.Ref{module: module, id: user_type_id, params: Enum.map(type_params, &eatf_type(module, &1))}
  end

  defp eatf_type(_module, _eatf) do
    %Type.Unsupported{}
  end
end
