defmodule DataSpecs.Loader do
  @moduledoc false

  alias DataSpecs.{Cache, Loader, Types}
  require Logger

  @literal_types [:atom, :integer]

  @zero_arity_builtin_types [:any, :pid, :reference, :atom, :boolean] ++
                              [:binary, :bitstring] ++
                              [:byte, :char, :arity] ++
                              [:number, :float, :integer, :neg_integer, :non_neg_integer, :pos_integer]

  @spec get(module(), Types.type_id(), arity()) :: Types.type_loader_fun()
  def get(module, type_id, type_arity) do
    case Cache.get(module, type_id, type_arity) do
      nil ->
        type_loaders = compile(module)
        Cache.set(type_loaders)

        Cache.get(module, type_id, type_arity) ||
          raise "Unknown type #{inspect(module)}.#{type_id}/#{type_arity}"

      type_loader ->
        type_loader
    end
  end

  defp compile(module) do
    module
    |> code_typespec_fetch_types()
    |> Enum.map(&type_loader(module, &1))
  end

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

  defp type_loader(module, {type, {type_id, eatf, type_params}}) do
    type_arity = length(type_params)

    eatf =
      case type do
        :type -> eatf
        :typep -> eatf
        :opaque -> :opaque
      end

    loader = eatf_loader(module, type_id, eatf, type_params)

    {{module, type_id, type_arity}, loader}
  end

  defp eatf_loader(module, type_id, :opaque, type_vars) do
    err_type_ref = "#{inspect(module)}.#{type_id}/#{length(type_vars)}"

    default_loader = fn _value, _custom_type_loaders, _type_params_loaders ->
      {:error, ["opaque type #{err_type_ref} has no custom type loader defined"]}
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, lineno, :term, []}, []) do
    eatf_loader(module, type_id, {:type, lineno, :any, []}, [])
  end

  defp eatf_loader(module, type_id, {literal_type, 0, literal}, []) when literal_type in @literal_types do
    # Example:
    #   @type t_literal_atom :: :a
    #
    #   erlang abstract type format:
    #     {:atom, 0, :a}
    #
    #   type_vars:
    #     []

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      apply(Loader.Builtin, literal_type, [value, custom_type_loaders, type_params_loaders])
      |> case do
        {:ok, ^literal} ->
          {:ok, literal}

        {:ok, _} ->
          {:error, ["value #{inspect(value)} doesn't match literal value #{inspect(literal)}"]}

        {:error, _} = error ->
          error
      end
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, builtin_type, []}, [])
       when builtin_type in @zero_arity_builtin_types do
    # Example:
    #   @type t_atom :: atom()
    #
    #   erlang abstract type format:
    #     {:type, 7, :atom, []}
    #
    #   type_vars:
    #     []

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      apply(Loader.Builtin, builtin_type, [value, custom_type_loaders, type_params_loaders])
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :binary, [{:integer, _, size}, {:integer, _, unit}]}, []) do
    # Example:
    #   @type t_bitstring_2 :: <<_::16, _::_*4>>
    #
    #   erlang abstract type format:
    #     {:type, 7, :binary, [{:integer, 0, 16}, {:integer, _, 4}]}
    #
    #   type_vars:
    #     []

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.binary(value, size, unit, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :range, [{:integer, 0, lower}, {:integer, 0, upper}]}, []) do
    # Example:
    #   @type t_range :: 1..10
    #
    #   erlang abstract type format:
    #     {:type, 7, :range, [{:integer, 0, 1}, {:integer, 0, 10}]}
    #
    #   type_vars:
    #     []

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.range(lower, upper, value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:var, _lineno, _var_id} = var, [var] = type_vars) do
    # Example:
    #   @type t(x) :: x
    #
    #   erlang abstract type format:
    #     {:var, 45, :x}
    #
    #   type_vars:
    #     [{:var, 45, :x}]

    type_params = [var]

    default_loader = fn value, custom_type_loaders, [_type_params_loader] = type_params_loaders ->
      [type_loader] = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      type_loader.(value, custom_type_loaders, [type_loader])
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :union, type_params}, type_vars) do
    # Example:
    #   @type t_union(x) :: x | atom() | integer()
    #
    #   erlang abstract type format:
    #     {:type, 9, :union, [{:var, 9, :x}, {:type, 9, :atom, []}, {:type, 9, :integer, []}]}
    #
    #   type_vars:
    #     [{:var, 9, :x}]

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loader.Builtin.union(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, nil, []}, []) do
    # Example:
    #   @type t_empty_list :: []
    #
    #   erlang abstract type format:
    #     {:type, 0, nil, []}

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.empty_list(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :list, type_params}, type_vars) do
    # Example:
    #   @type t_list :: [atom()]
    #
    #   erlang abstract type format:
    #     {:type, 0, :list, [{:type, 6, :atom, []}]}
    #
    #   type_vars:
    #     []

    type_params =
      case type_params do
        [] ->
          [{:type, 0, :any, []}]

        _ ->
          type_params
      end

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loader.Builtin.list(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :nonempty_list, type_params}, type_vars) do
    # Example:
    #   @type t_nonempty_list :: [atom(), ...]
    #
    #   erlang abstract type format:
    #     {:type, 0, ::nonempty_list, [{:type, 9, :atom, []}]}
    #
    #   type_vars:
    #     []

    type_params =
      case type_params do
        [] ->
          [{:type, 0, :any, []}]

        _ ->
          type_params
      end

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loader.Builtin.nonempty_list(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :tuple, :any}, []) do
    # Example:
    #   @type t_tuple_any_size :: tuple()
    #
    #   erlang abstract type format:
    #     {:type, 31, :tuple, :any}

    default_loader = fn value, custom_type_loaders, [] ->
      Loader.Builtin.tuple_any(value, custom_type_loaders, [])
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :tuple, type_params}, type_vars) do
    # Example:
    #   @type t_user_type_param(x, y) :: {integer(), x, y}
    #
    #   erlang abstract type format:
    #     {:type, 4, :tuple, [{:type, 4, :integer, []}, {:var, 4, :x}, {:var, 4, :y}]}
    #
    #   type_vars:
    #     [{:var, 4, :x}, {:var, 4, :y}]

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loader.Builtin.tuple(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(
         module,
         type_id,
         {:type, lineno, :map,
          [{:type, _, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, module}]} | kv_type_params]},
         type_vars
       ) do
    # Example:
    #   @type t :: %__MODULE__{
    #     f_1: atom(),
    #     f_2: integer()
    #   }
    #
    #   erlang abstract type format:
    #     {:type, 48, :map,
    #       [
    #         {:type, 48, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, Test.DataSpecs.SampleStructType}]},
    #         {:type, 48, :map_field_exact, [{:atom, 0, :f_1}, {:type, 49, :atom, []}]},
    #         {:type, 48, :map_field_exact, [{:atom, 0, :f_2}, {:type, 50, :integer, []}]}
    #       ]
    #     }

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      kv_type_params =
        Enum.map(kv_type_params, fn {:type, lineno, :map_field_exact, type_params} ->
          {:type, lineno, :map_field_assoc, type_params}
        end)

      map_loader = eatf_loader(module, type_id, {:type, lineno, :map, kv_type_params}, type_vars)

      map_loader.(value, custom_type_loaders, type_params_loaders)
      |> case do
        {:ok, loaded_map} ->
          try do
            {:ok, struct!(module, loaded_map)}
          rescue
            exception in [ArgumentError] ->
              {:error, [exception.message]}
          end

        {:error, errors} ->
          {:error, ["can't convert #{inspect(value)} to a %#{inspect(module)}{} struct", errors]}
      end
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :map, []}, []) do
    # Example:
    #   @type t_empty_map :: %{}
    #
    #   erlang abstract type format:
    #     {:type, 36, :map, []}

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      Loader.Builtin.empty_map(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, 0}, default_loader)
  end

  defp eatf_loader(module, type_id, {:type, _lineno, :map, kv_type_params}, type_vars) do
    # Example:
    #   @type t_map_3 :: %{required(atom()) => integer(), optional(integer()) => atom()}
    #
    #   erlang abstract type format:
    #     {:type, 38, :map, [
    #       {:type, 38, :map_field_exact, [{:atom, 0, :a}, {:type, 38, :integer, []}]},
    #       {:type, 38, :map_field_assoc, [{:type, 38, :integer, []}, {:type, 38, :atom, []}]}
    #     ]}

    {kv_req_type_params, kv_opt_type_params} =
      Enum.split_with(kv_type_params, &match?({:type, _, :map_field_exact, _}, &1))

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      with {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, errors}} <-
             map_req_kv(
               value,
               custom_type_loaders,
               type_params_loaders,
               module,
               type_id,
               type_vars,
               kv_req_type_params
             ),
           {:ok, {value_with_unprocessed_kv, value_with_processed_kv, _errors}} <-
             map_opt_kv(
               value_with_unprocessed_kv,
               value_with_req_processed_kv,
               custom_type_loaders,
               type_params_loaders,
               module,
               type_id,
               type_vars,
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

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(module, _type_id, {:user_type, _lineno, user_type_id, type_params}, type_vars) do
    # Example:
    #   @type xxx :: t_user_type_param(integer(), integer())
    #
    #   erlang abstract type format:
    #     {:user_type, 6, :t_user_type_param, [{:type, 6, :integer, []}, {:type, 6, :integer, []}]}

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, user_type_id, type_params, type_params_loaders, type_vars)

      type_loader = get(module, user_type_id, length(type_params))
      type_loader.(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, user_type_id, length(type_vars)}, default_loader)
  end

  defp eatf_loader(
         module,
         type_id,
         {:remote_type, _lineno, [{:atom, _, remote_module}, {:atom, _, remote_type_id}, remote_type_params]},
         type_vars
       ) do
    # Example:
    #   @type t_mapset :: MapSet.t(integer())
    #
    #   erlang abstract type format:
    #     {:remote_type, 46, [{:atom, 0, MapSet}, {:atom, 0, :t}, [{:type, 46, :integer, []}]]}

    default_loader = fn value, custom_type_loaders, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(
          module,
          type_id,
          remote_type_params,
          type_params_loaders,
          type_vars
        )

      type_loader = get(remote_module, remote_type_id, length(remote_type_params))
      type_loader.(value, custom_type_loaders, type_params_loaders)
    end

    maybe_custom_loader({module, type_id, length(type_vars)}, default_loader)
  end

  # coveralls-ignore-start

  defp eatf_loader(module, type_id, eatf, type_params) do
    err_type_ref = "#{inspect(module)}.#{type_id}/#{length(type_params)}"
    err_eaf = "erl_abstract_format: #{inspect(eatf)}"
    err_type_vars = "type_vars: #{inspect(type_params)}"
    err_message = "Type loader not implemented type: #{err_type_ref}, #{err_eaf}, #{err_type_vars}"

    Logger.info(err_message)

    fn _value, _custom_type_loaders, _type_params_loaders ->
      {:error, [err_message]}
    end
  end

  # coveralls-ignore-end

  defp maybe_custom_loader({_module, _type, _arity} = type_ref, default_loader) do
    fn value, custom_type_loaders, type_params_loaders ->
      loader = Map.get(custom_type_loaders, type_ref, default_loader)
      loader.(value, custom_type_loaders, type_params_loaders)
    end
  end

  defp type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars) do
    if length(type_vars) != length(type_params_loaders) do
      raise "Wrong number of type params for #{module}.#{type_id}/#{length(type_vars)}, got #{length(type_params_loaders)}"
    end

    type_vars_2_loader =
      type_vars
      |> Enum.zip(type_params_loaders)
      |> Map.new()

    Enum.map(type_params, fn
      {:var, _lineno, _var_id} = var ->
        Map.fetch!(type_vars_2_loader, var)

      {literal_type, 0, _literal} = eatf ->
        eatf_loader(module, literal_type, eatf, [])

      {type, _lineno, type_id, _type_params} = eatf when type in [:type, :typep, :user_type] ->
        eatf_loader(module, type_id, eatf, [])

      {:remote_type, _lineno, [{:atom, _, remote_module}, {:atom, _, remote_type_id}, _remote_type_params]} = eatf ->
        eatf_loader(remote_module, remote_type_id, eatf, [])
    end)
  end

  defp map_req_kv(value, custom_type_loaders, type_params_loaders, module, type_id, type_vars, kv_req_type_params) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value, %{}, []}}, fn
      {:type, _lineno, :map_field_exact, [_key, _value] = type_params},
      {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, map_errors}} ->
        type_params = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

        Loader.Builtin.map_field_required(value_with_unprocessed_kv, custom_type_loaders, type_params)
        |> case do
          {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv_new, errors}} ->
            value_with_req_processed_kv = Map.merge(value_with_req_processed_kv, value_with_req_processed_kv_new)
            {:cont, {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, map_errors ++ errors}}}

          {:error, _} = error ->
            {:halt, error}
        end
    end)
  end

  defp map_opt_kv(
         value_with_unprocessed_kv,
         value_with_req_processed_kv,
         custom_type_loaders,
         type_params_loaders,
         module,
         type_id,
         type_vars,
         kv_req_type_params
       ) do
    Enum.reduce_while(kv_req_type_params, {:ok, {value_with_unprocessed_kv, value_with_req_processed_kv, []}}, fn
      {:type, _lineno, :map_field_assoc, [_key, _value] = type_params},
      {:ok, {value_with_unprocessed_kv, value_with_processed_kv, map_errors}} ->
        type_params = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

        Loader.Builtin.map_field_optional(value_with_unprocessed_kv, custom_type_loaders, type_params)
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
