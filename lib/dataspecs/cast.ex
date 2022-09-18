defmodule DataSpecs.Cast do
  @moduledoc false

  alias DataSpecs.{Cache, Cast, Schema, Types}
  alias DataSpecs.Schema.Type
  require DataSpecs.Schema.Type
  require Logger

  @spec get(module(), Types.type_id(), arity()) :: Types.type_cast_fun()
  def get(module, type_id, type_arity) do
    case Cache.get(module, type_id, type_arity) do
      nil ->
        type_casts = build(module)
        Cache.set(type_casts)

        Cache.get(module, type_id, type_arity) ||
          raise "Unknown type #{inspect(module)}.#{type_id}/#{type_arity}"

      type_cast ->
        type_cast
    end
  end

  @spec build(module()) :: [{Types.mta(), Types.type_cast_fun()}]
  defp build(module) do
    module
    |> Schema.load()
    |> Enum.map(fn %Type{} = t ->
      {{t.module, t.id, length(t.vars)}, cast(t)}
    end)
  end

  @spec cast(Type.t(), nil | [Types.type_cast_fun()]) :: Types.type_cast_fun()
  defp cast(type, force_type_params_casts \\ nil)

  defp cast(%Type{visibility: :opaque} = t, _force_type_params_casts) do
    err_type_ref = Type.format_typeref(t)

    default_cast = fn _value, _custom_type_casts, _type_params_casts ->
      {:error, ["opaque type #{err_type_ref} has no custom type cast defined"]}
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %literal_type{value: literal}} = t, _force_type_params_casts)
       when literal_type in [Type.Literal.Atom, Type.Literal.Integer] do
    cast_builtin_fun =
      case literal_type do
        Type.Literal.Atom -> &Cast.Builtin.atom/3
        Type.Literal.Integer -> &Cast.Builtin.integer/3
      end

    default_cast = fn value, custom_type_casts, type_params_casts ->
      cast_builtin_fun.(value, custom_type_casts, type_params_casts)
      |> case do
        {:ok, ^literal} -> {:ok, literal}
        {:ok, _} -> {:error, ["value #{inspect(value)} doesn't match literal value #{inspect(literal)}"]}
        {:error, _} = error -> error
      end
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Builtin{id: builtin_type}} = t, _force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      apply(Cast.Builtin, builtin_type, [value, custom_type_casts, type_params_casts])
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Bitstring{size: size, unit: unit}} = t, _force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      Cast.Builtin.binary(value, size, unit, custom_type_casts, type_params_casts)
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Range{lower: lower, upper: upper}} = t, _force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      Cast.Builtin.range(lower, upper, value, custom_type_casts, type_params_casts)
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Var{} = var, vars: [var]} = t, _force_type_params_casts) do
    default_cast = fn value, custom_type_casts, [_type_params_cast] = type_params_casts ->
      [type_cast] = type_params_var_expansion(t.module, [var], type_params_casts, t.vars)

      type_cast.(value, custom_type_casts, [type_cast])
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Union{}} = t, force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      type_params_casts =
        type_params_var_expansion(t.module, t.type.of, force_type_params_casts || type_params_casts, t.vars)

      Cast.Builtin.union(value, custom_type_casts, type_params_casts)
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.List{}} = t, force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      type_params_casts =
        type_params_var_expansion(t.module, [t.type.of], force_type_params_casts || type_params_casts, t.vars)

      case t.type.cardinality do
        0 -> Cast.Builtin.empty_list(value, custom_type_casts, type_params_casts)
        :* -> Cast.Builtin.list(value, custom_type_casts, type_params_casts)
        :+ -> Cast.Builtin.nonempty_list(value, custom_type_casts, type_params_casts)
      end
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Tuple{}} = t, force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      type_params_casts =
        type_params_var_expansion(t.module, t.type.of, force_type_params_casts || type_params_casts, t.vars)

      case t.type.cardinality do
        :* -> Cast.Builtin.tuple_any(value, custom_type_casts, type_params_casts)
        _ -> Cast.Builtin.tuple(value, custom_type_casts, type_params_casts)
      end
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Ref{}} = t, force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      type_params_casts =
        type_params_var_expansion(
          t.module,
          t.type.params,
          force_type_params_casts || type_params_casts,
          t.vars
        )

      type_cast = get(t.type.module, t.type.id, length(t.type.params))
      type_cast.(value, custom_type_casts, type_params_casts)
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Unsupported{}}, _force_type_params_casts) do
    Logger.info("Unsupported type")

    fn _value, _custom_type_casts, _type_params_casts ->
      {:error, ["Unsupported Type"]}
    end
  end

  defp cast(%Type{type: %Type.Map{struct: nil, of: []}} = t, _force_type_params_casts) do
    default_cast = fn value, custom_type_casts, type_params_casts ->
      Cast.Builtin.empty_map(value, custom_type_casts, type_params_casts)
    end

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Map{struct: nil}} = t, force_type_params_casts) do
    {kv_req_type_params, kv_opt_type_params} =
      Enum.split_with(t.type.of, fn {%Type.Map.Key{required?: required?}, _v} -> required? end)

    default_cast = fn value, custom_type_casts, type_params_casts ->
      with {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, errors}} <-
             map_req_kv(
               t,
               value,
               custom_type_casts,
               type_params_casts,
               force_type_params_casts,
               kv_req_type_params
             ),
           {:ok, {value_with_unprocessed_kv, value_with_processed_kv, _errors}} <-
             map_opt_kv(
               t,
               value_with_unprocessed_kv,
               value_with_req_processed_kv,
               custom_type_casts,
               type_params_casts,
               force_type_params_casts,
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

    maybe_custom_cast(t, default_cast)
  end

  defp cast(%Type{type: %Type.Map{struct: struct_module}} = t, force_type_params_casts) do
    t =
      t
      |> put_in([Access.key!(:type), Access.key!(:of), Access.all(), Access.elem(0), Access.key!(:required?)], false)
      |> put_in([Access.key!(:type), Access.key!(:struct)], nil)

    default_cast = fn value, custom_type_casts, type_params_casts ->
      map_cast = cast(t, force_type_params_casts)

      map_cast.(value, custom_type_casts, type_params_casts)
      |> case do
        {:ok, casted_map} ->
          try do
            {:ok, struct!(struct_module, casted_map)}
          rescue
            exception in [ArgumentError] ->
              {:error, [exception.message]}
          end

        {:error, errors} ->
          {:error, ["can't convert #{inspect(value)} to a %#{inspect(struct_module)}{} struct", errors]}
      end
    end

    maybe_custom_cast(t, default_cast)
  end

  @spec maybe_custom_cast(Type.t(), Types.type_cast_fun()) :: Types.type_cast_fun()
  defp maybe_custom_cast(%Type{} = t, default_cast) do
    type_ref = {t.module, t.id, length(t.vars)}

    fn value, custom_type_casts, type_params_casts ->
      cast = Map.get(custom_type_casts, type_ref, default_cast)
      cast.(value, custom_type_casts, type_params_casts)
    end
  end

  @spec type_params_var_expansion(module(), [Type.type()], [Types.type_cast_fun()], [Type.Var.t()]) ::
          [Types.type_cast_fun()]
  defp type_params_var_expansion(module, type_params, type_vars_cast, type_vars) do
    type_vars_2_cast = Map.new(Enum.zip(type_vars, type_vars_cast))

    Enum.map(type_params, fn
      %Type.Var{} = var ->
        Map.fetch!(type_vars_2_cast, var)

      type ->
        anonymous_type = Schema.Anonymous.build(module, type)
        anonymous_type_vars_cast = Enum.map(anonymous_type.vars, &Map.fetch!(type_vars_2_cast, &1))

        cast(anonymous_type, anonymous_type_vars_cast)
    end)
  end

  @spec map_req_kv(
          Type.t(),
          Types.value(),
          Types.custom_type_casts(),
          [Types.type_cast_fun()],
          nil | [Types.type_cast_fun()],
          [Type.Map.kv()]
        ) :: Cast.Builtin.map_field_res()
  defp map_req_kv(
         %Type{} = type,
         value,
         custom_type_casts,
         type_params_casts,
         force_type_params_casts,
         kv_req_type_params
       ) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value, %{}, []}}, fn
      {%Type.Map.Key{required?: true, type: key_type}, value_type},
      {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, map_errors}} ->
        type_params_casts =
          type_params_var_expansion(
            type.module,
            [key_type, value_type],
            force_type_params_casts || type_params_casts,
            type.vars
          )

        Cast.Builtin.map_field_required(value_with_unprocessed_kv, custom_type_casts, type_params_casts)
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
          Types.custom_type_casts(),
          [Types.type_cast_fun()],
          nil | [Types.type_cast_fun()],
          [Type.Map.kv()]
        ) :: Cast.Builtin.map_field_res()
  defp map_opt_kv(
         %Type{} = type,
         value_with_unprocessed_kv,
         value_with_req_processed_kv,
         custom_type_casts,
         type_params_casts,
         force_type_params_casts,
         kv_req_type_params
       ) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, []}}, fn
      {%Type.Map.Key{required?: false, type: key_type}, value_type},
      {:ok, {value_with_unprocessed_kv, value_with_processed_kv, map_errors}} ->
        type_params_casts =
          type_params_var_expansion(
            type.module,
            [key_type, value_type],
            force_type_params_casts || type_params_casts,
            type.vars
          )

        Cast.Builtin.map_field_optional(value_with_unprocessed_kv, custom_type_casts, type_params_casts)
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
