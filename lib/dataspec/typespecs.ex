defmodule DataSpec.Typespecs do
  alias DataSpec.{Error, Loaders}

  require Logger

  def loader(module, type_id, type_arity) do
    type = {type_id, type_arity}
    type_loaders_map = compile(module)

    if Map.has_key?(type_loaders_map, type) do
      type_loaders_map[type]
    else
      raise Error, "Unknown type #{inspect(module)}.#{type_id}/#{type_arity}"
    end
  end

  defp compile(module) do
    # TODO cache in ETS

    module
    |> fetch_types()
    |> Enum.map(&type_loader(module, &1))
    |> Map.new()
  end

  defp fetch_types(module) do
    {:ok, eaf_types} = Code.Typespec.fetch_types(module)
    eaf_types
  end

  defp type_loader(module, {type, {type_id, eatf, type_params}}) do
    type_arity = length(type_params)

    loader =
      case type do
        :type ->
          eatf_loader(module, type_id, eatf, type_params)

        :typep ->
          eatf_loader(module, type_id, eatf, type_params)

        :opaque ->
          # TODO use optional custom user defined loader
          eatf_loader(module, type_id, {:type, 0, :any, []}, [])
      end

    {{type_id, type_arity}, loader}
  end

  @literal_types [:atom, :integer]
  defp eatf_loader(_module, _type_id, {literal_type, 0, literal}, []) when literal_type in @literal_types do
    &Loaders.literal(literal, &1, &2)
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :any, []}, []) do
    &Loaders.any/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :term, []}, []) do
    &Loaders.any/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :pid, []}, []) do
    &Loaders.pid/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :reference, []}, []) do
    &Loaders.reference/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :atom, []}, []) do
    &Loaders.atom/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :boolean, []}, []) do
    &Loaders.boolean/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :binary, []}, []) do
    &Loaders.binary/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :number, []}, []) do
    &Loaders.number/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :float, []}, []) do
    &Loaders.float/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :integer, []}, []) do
    &Loaders.integer/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :neg_integer, []}, []) do
    &Loaders.neg_integer/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :non_neg_integer, []}, []) do
    &Loaders.non_neg_integer/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :pos_integer, []}, []) do
    &Loaders.pos_integer/2
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :range, [{:integer, 0, lower}, {:integer, 0, upper}]}, []) do
    &Loaders.range(lower, upper, &1, &2)
  end

  defp eatf_loader(module, type_id, {:var, _lineno, _id} = var, [var] = type_vars) do
    # Example:
    #   @type t(x) :: x
    #
    #   erlang abstract type format:
    #     {:var, 45, :x}
    #
    #   type_vars:
    #     [{:var, 45, :x}]

    type_params = [var]

    fn value, [_type_params_loader] = type_params_loaders ->
      [type_loaders] = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      type_loaders.(value, [type_loaders])
    end
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

    fn value, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loaders.union(value, type_params_loaders)
    end
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, nil, []}, []) do
    # Example:
    #   @type t_empty_list :: []
    #
    #   erlang abstract type format:
    #     {:type, 0, nil, []}

    &Loaders.empty_list/2
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

    fn value, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loaders.list(value, type_params_loaders)
    end
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
        [] -> [{:type, 0, :any, []}]
        _ -> type_params
      end

    fn value, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loaders.nonempty_list(value, type_params_loaders)
    end
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

    fn value, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      Loaders.tuple(value, type_params_loaders)
    end
  end

  defp eatf_loader(
         module,
         type_id,
         {:type, lineno, :map,
          [{:type, _, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, struct_module}]} | kv_type_params]},
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
    #         {:type, 48, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, Test.DataSpec.SampleStructType}]},
    #         {:type, 48, :map_field_exact, [{:atom, 0, :f_1}, {:type, 49, :atom, []}]},
    #         {:type, 48, :map_field_exact, [{:atom, 0, :f_2}, {:type, 50, :integer, []}]}
    #       ]
    #     }

    fn value, type_params_loaders ->
      kv_type_params =
        Enum.map(kv_type_params, fn {:type, lineno, :map_field_exact, type_params} ->
          {:type, lineno, :map_field_assoc, type_params}
        end)

      map_loader = eatf_loader(module, type_id, {:type, lineno, :map, kv_type_params}, type_vars)
      map = map_loader.(value, type_params_loaders)

      try do
        struct!(struct_module, map)
      rescue
        err in [ArgumentError] ->
          raise Error, err.message
      end
    end
  end

  defp eatf_loader(_module, _type_id, {:type, _lineno, :map, []}, []) do
    # Example:
    #   @type t_empty_map :: %{}
    #
    #   erlang abstract type format:
    #     {:type, 36, :map, []}

    &Loaders.empty_map/2
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

    {kv_required_type_params, kv_optional_type_params} =
      Enum.split_with(kv_type_params, &match?({:type, _, :map_field_exact, _}, &1))

    fn value, type_params_loaders ->
      {value_rest, value_processed} =
        Enum.reduce(kv_required_type_params, {value, %{}}, fn
          {:type, _lineno, :map_field_exact, type_params}, {value_rest, value_processed} ->
            type_params = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)
            {value_rest, value_processed_new} = Loaders.map_field_required(value_rest, type_params)
            {value_rest, Map.merge(value_processed, value_processed_new)}
        end)

      {value_rest, value_processed} =
        Enum.reduce(kv_optional_type_params, {value_rest, value_processed}, fn
          {:type, _lineno, :map_field_assoc, type_params}, {value_rest, value_processed} ->
            type_params = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)
            {value_rest, value_processed_new} = Loaders.map_field_optional(value_rest, type_params)
            {value_rest, Map.merge(value_processed, value_processed_new)}
        end)

      if value_rest == %{} do
        value_processed
      else
        raise Error, "can't convert #{inspect(value)} to a map, bad k/v #{inspect(value_rest)}"
      end
    end
  end

  defp eatf_loader(module, _type_id, {:user_type, _lineno, type_id, type_params}, type_vars) do
    # Example:
    #   @type xxx :: t_user_type_param(integer(), integer())
    #
    #   erlang abstract type format:
    #     {:user_type, 6, :t_user_type_param, [{:type, 6, :integer, []}, {:type, 6, :integer, []}]}

    fn value, type_params_loaders ->
      type_params_loaders = type_params_var_expansion(module, type_id, type_params, type_params_loaders, type_vars)

      type_loader = loader(module, type_id, length(type_params))
      type_loader.(value, type_params_loaders)
    end
  end

  defp eatf_loader(
         _module,
         _type_id,
         {:remote_type, _lineno, [{:atom, _, remote_module}, {:atom, _, remote_type}, remote_type_params]},
         type_vars
       ) do
    # Example:
    #   @type t_mapset :: MapSet.t(integer())
    #
    #   erlang abstract type format:
    #     {:remote_type, 46, [{:atom, 0, MapSet}, {:atom, 0, :t}, [{:type, 46, :integer, []}]]}

    fn value, type_params_loaders ->
      type_params_loaders =
        type_params_var_expansion(remote_module, remote_type, remote_type_params, type_params_loaders, type_vars)

      type_loader = loader(remote_module, remote_type, length(remote_type_params))
      type_loader.(value, type_params_loaders)
    end
  end

  defp eatf_loader(module, type_id, eatf, type_params) do
    Logger.info("""
    Type loader not implemented
    type: #{inspect(module)}.#{type_id}/#{length(type_params)}
    erl_abstract_format: #{inspect(eatf)}
    type_vars: #{inspect(type_params)}
    """)
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
      {:var, _, _} = var -> Map.fetch!(type_vars_2_loader, var)
      {literal_type, 0, _literal} = eatf -> eatf_loader(module, literal_type, eatf, [])
      {_, _, type_id, _} = eatf -> eatf_loader(module, type_id, eatf, [])
    end)
  end
end
