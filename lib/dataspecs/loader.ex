defmodule DataSpecs.Loader do
  @moduledoc false

  alias DataSpecs.{Cache, Loader, Schema, Types}
  alias DataSpecs.Schema.Type
  require DataSpecs.Schema.Type
  require Logger

  @spec get(module(), Types.type_id(), arity()) :: Types.type_loader_fun()
  def get(module, type_id, type_arity) do
    case Cache.get(module, type_id, type_arity) do
      nil ->
        type_loaders = build(module)
        Cache.set(type_loaders)

        Cache.get(module, type_id, type_arity) ||
          raise "Unknown type #{inspect(module)}.#{type_id}/#{type_arity}"

      type_loader ->
        type_loader
    end
  end

  @spec build(module()) :: [{Types.custom_type_ref(), Types.type_loader_fun()}]
  defp build(module) do
    module
    |> Schema.load()
    |> Enum.map(fn %Type{} = t ->
      {{t.module, t.id, length(t.vars)}, loader(t)}
    end)
  end

  @spec loader(Type.t(), nil | [Types.type_loader_fun()]) :: Types.type_loader_fun()
  defp loader(type, force_type_params_loaders \\ nil)

  defp loader(%Type{visibility: :opaque} = t, _xxx_type_params_loaders) do
    err_type_ref = Type.format_typeref(t)

    default_loader = fn _value, _custom_type_loaders, _type_params_loaders ->
      {:error, ["opaque type #{err_type_ref} has no custom type loader defined"]}
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %literal_type{value: literal}} = t, _xxx_type_params_loaders)
       when literal_type in [Type.Literal.Atom, Type.Literal.Integer] do
    loader_builtin_fun =
      case literal_type do
        Type.Literal.Atom -> &Loader.Builtin.atom/3
        Type.Literal.Integer -> &Loader.Builtin.integer/3
      end

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      loader_builtin_fun.(value, custom_type_loaders, type_params_loaders)
      |> case do
        {:ok, ^literal} -> {:ok, literal}
        {:ok, _} -> {:error, ["value #{inspect(value)} doesn't match literal value #{inspect(literal)}"]}
        {:error, _} = error -> error
      end
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Builtin{id: builtin_type}} = t, _xxx_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      apply(Loader.Builtin, builtin_type, [value, custom_type_loaders, type_params_loaders])
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Bitstring{size: size, unit: unit}} = t, _xxx_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.binary(value, size, unit, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Range{lower: lower, upper: upper}} = t, _xxx_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.range(lower, upper, value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Var{} = var, vars: [var]} = t, _xxx_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, [_type_params_loader] = type_params_loaders ->
      [type_loader] = type_params_var_expansion(t.module, [var], type_params_loaders, t.vars)

      type_loader.(value, custom_type_loaders, [type_loader])
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Union{}} = t, force_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(t.module, t.type.of, force_type_params_loaders || type_params_loaders, t.vars)

      Loader.Builtin.union(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.List{}} = t, force_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(t.module, [t.type.of], force_type_params_loaders || type_params_loaders, t.vars)

      case t.type.cardinality do
        0 -> Loader.Builtin.empty_list(value, custom_type_loaders, type_params_loaders)
        :* -> Loader.Builtin.list(value, custom_type_loaders, type_params_loaders)
        :+ -> Loader.Builtin.nonempty_list(value, custom_type_loaders, type_params_loaders)
      end
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Tuple{}} = t, force_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(t.module, t.type.of, force_type_params_loaders || type_params_loaders, t.vars)

      case t.type.cardinality do
        :* -> Loader.Builtin.tuple_any(value, custom_type_loaders, type_params_loaders)
        _ -> Loader.Builtin.tuple(value, custom_type_loaders, type_params_loaders)
      end
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Ref{}} = t, force_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(
          t.module,
          t.type.params,
          force_type_params_loaders || type_params_loaders,
          t.vars
        )

      type_loader = get(t.type.module, t.type.id, length(t.type.params))
      type_loader.(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Unsupported{}}, _xxx_type_params_loaders) do
    Logger.info("Unsupported type")

    fn _value, _custom_type_loaders, _type_params_loaders ->
      {:error, ["Unsupported Type"]}
    end
  end

  defp loader(%Type{type: %Type.Map{struct: nil, of: []}} = t, _xxx_type_params_loaders) do
    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.empty_map(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Map{struct: nil}} = t, force_type_params_loaders) do
    {kv_req_type_params, kv_opt_type_params} =
      Enum.split_with(t.type.of, fn {%Type.Map.Key{required?: required?}, _v} -> required? end)

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      with {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, errors}} <-
             map_req_kv(
               t,
               value,
               custom_type_loaders,
               type_params_loaders,
               force_type_params_loaders,
               kv_req_type_params
             ),
           {:ok, {value_with_unprocessed_kv, value_with_processed_kv, _errors}} <-
             map_opt_kv(
               t,
               value_with_unprocessed_kv,
               value_with_req_processed_kv,
               custom_type_loaders,
               type_params_loaders,
               force_type_params_loaders,
               kv_opt_type_params
             ) do
        if value_with_unprocessed_kv == %{} do
          {:ok, value_with_processed_kv}
        else
          error = "can't convert #{inspect(value)} to a map, bad k/v pairs: #{inspect(value_with_unprocessed_kv)}"
          {:error, [error, errors]}
        end
      else
        {:error, _} = error ->
          error
      end
    end

    maybe_custom_loader(t, default_loader)
  end

  defp loader(%Type{type: %Type.Map{struct: struct_module}} = t, force_type_params_loaders) do
    t =
      t
      |> put_in([Access.key!(:type), Access.key!(:of), Access.all(), Access.elem(0), Access.key!(:required?)], false)
      |> put_in([Access.key!(:type), Access.key!(:struct)], nil)

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      map_loader = loader(t, force_type_params_loaders)

      map_loader.(value, custom_type_loaders, type_params_loaders)
      |> case do
        {:ok, loaded_map} ->
          try do
            {:ok, struct!(struct_module, loaded_map)}
          rescue
            exception in [ArgumentError] ->
              {:error, [exception.message]}
          end

        {:error, errors} ->
          {:error, ["can't convert #{inspect(value)} to a %#{inspect(struct_module)}{} struct", errors]}
      end
    end

    maybe_custom_loader(t, default_loader)
  end

  @spec maybe_custom_loader(Type.t(), Types.type_loader_fun()) :: Types.type_loader_fun()
  defp maybe_custom_loader(%Type{} = t, default_loader) do
    type_ref = {t.module, t.id, length(t.vars)}

    fn value, custom_type_loaders, type_params_loaders ->
      loader = Map.get(custom_type_loaders, type_ref, default_loader)
      loader.(value, custom_type_loaders, type_params_loaders)
    end
  end

  @spec type_params_var_expansion(module(), [Type.type()], [Types.type_loader_fun()], [Type.Var.t()]) ::
          [Types.type_loader_fun()]
  defp type_params_var_expansion(module, type_params, type_vars_loader, type_vars) do
    type_vars_2_loader = Map.new(Enum.zip(type_vars, type_vars_loader))

    Enum.map(type_params, fn
      %Type.Var{} = var ->
        Map.fetch!(type_vars_2_loader, var)

      type ->
        anonymous_type = Schema.Anonymous.build(module, type)
        anonymous_type_vars_loader = Enum.map(anonymous_type.vars, &Map.fetch!(type_vars_2_loader, &1))

        loader(anonymous_type, anonymous_type_vars_loader)
    end)
  end

  @spec map_req_kv(
          Type.t(),
          Types.value(),
          Types.custom_type_loaders(),
          [Types.type_loader_fun()],
          nil | [Types.type_loader_fun()],
          [Type.Map.kv()]
        ) :: Loader.Builtin.map_field_res()
  defp map_req_kv(
         %Type{} = type,
         value,
         custom_type_loaders,
         type_params_loaders,
         force_type_params_loaders,
         kv_req_type_params
       ) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value, %{}, []}}, fn
      {%Type.Map.Key{required?: true, type: key_type}, value_type},
      {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, map_errors}} ->
        type_params_loaders =
          type_params_var_expansion(
            type.module,
            [key_type, value_type],
            force_type_params_loaders || type_params_loaders,
            type.vars
          )

        Loader.Builtin.map_field_required(value_with_unprocessed_kv, custom_type_loaders, type_params_loaders)
        |> case do
          {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv_new, errors}} ->
            value_with_req_processed_kv = Map.merge(value_with_req_processed_kv, value_with_req_processed_kv_new)
            {:cont, {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, map_errors ++ errors}}}

          {:error, _} = error ->
            {:halt, error}
        end
    end)
  end

  @spec map_opt_kv(
          Type.t(),
          map(),
          map(),
          Types.custom_type_loaders(),
          [Types.type_loader_fun()],
          nil | [Types.type_loader_fun()],
          [Type.Map.kv()]
        ) :: Loader.Builtin.map_field_res()
  defp map_opt_kv(
         %Type{} = type,
         value_with_unprocessed_kv,
         value_with_req_processed_kv,
         custom_type_loaders,
         type_params_loaders,
         force_type_params_loaders,
         kv_req_type_params
       ) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, []}}, fn
      {%Type.Map.Key{required?: false, type: key_type}, value_type},
      {:ok, {value_with_unprocessed_kv, value_with_processed_kv, map_errors}} ->
        type_params_loaders =
          type_params_var_expansion(
            type.module,
            [key_type, value_type],
            force_type_params_loaders || type_params_loaders,
            type.vars
          )

        Loader.Builtin.map_field_optional(value_with_unprocessed_kv, custom_type_loaders, type_params_loaders)
        |> case do
          {:ok, {value_with_unprocessed_kv, value_with_processed_kv_new, errors}} ->
            value_with_processed_kv = Map.merge(value_with_processed_kv, value_with_processed_kv_new)
            {:cont, {:ok, {value_with_unprocessed_kv, value_with_processed_kv, map_errors ++ errors}}}

          {:error, _} = error ->
            {:halt, error}
        end
    end)
  end
end
