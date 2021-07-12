defmodule DataSpec.Typespecs do
  alias DataSpec.{Error, Types}

  def parser(module, type) do
    module
    |> compile()
    |> Map.fetch!(type)
  end

  defp compile(module) do
    # TODO cache in ETS

    module
    |> Code.Typespec.fetch_types()
    |> then(fn {:ok, eaf_types} -> eaf_types end)
    # |> IO.inspect()
    |> Enum.map(&type_processor(module, &1))
    |> Map.new()
  end

  defp type_processor(module, {type, {type_id, eatf, type_params}}) do
    case type do
      :type -> {type_id, eatf_processor(module, type_id, eatf, type_params)}
      :typep -> raise "TODO"
      :opaque -> raise "TODO"
    end
  end

  @literal_types [:atom, :integer]
  defp eatf_processor(_module, _type_id, {literal_type, 0, literal}, []) when literal_type in @literal_types do
    &Types.literal(literal, &1, &2)
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :any, []}, []) do
    &Types.any/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :pid, []}, []) do
    &Types.pid/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :reference, []}, []) do
    &Types.reference/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :atom, []}, []) do
    &Types.atom/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :float, []}, []) do
    &Types.float/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :integer, []}, []) do
    &Types.integer/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :neg_integer, []}, []) do
    &Types.neg_integer/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :non_neg_integer, []}, []) do
    &Types.non_neg_integer/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :pos_integer, []}, []) do
    &Types.pos_integer/2
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :range, [{:integer, 0, lower}, {:integer, 0, upper}]}, []) do
    &Types.range(lower, upper, &1, &2)
  end

  defp eatf_processor(module, type_id, {:type, _lineno, :union, type_params}, type_vars) do
    # Example:
    #   @type t_union(x) :: x | atom() | integer()
    #
    #   erlang abstract type format:
    #     {:type, 9, :union, [{:var, 9, :x}, {:type, 9, :atom, []}, {:type, 9, :integer, []}]}
    #
    #   type_vars:
    #     [{:var, 9, :x}]

    fn value, type_params_processors ->
      type_params_processors =
        type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)

      Types.union(value, type_params_processors)
    end
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, nil, []}, []) do
    # Example:
    #   @type t_empty_list :: []
    #
    #   erlang abstract type format:
    #     {:type, 0, nil, []}

    &Types.empty_list/2
  end

  defp eatf_processor(module, type_id, {:type, _lineno, :list, type_params}, type_vars) do
    # Example:
    #   @type t_list :: [atom()]
    #
    #   erlang abstract type format:
    #     {:type, 0, :list, [{:type, 6, :atom, []}]}
    #
    #   type_vars:
    #     []

    fn value, type_params_processors ->
      type_params_processors =
        type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)

      Types.list(value, type_params_processors)
    end
  end

  defp eatf_processor(module, type_id, {:type, _lineno, :nonempty_list, type_params}, type_vars) do
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

    fn value, type_params_processors ->
      type_params_processors =
        type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)

      Types.nonempty_list(value, type_params_processors)
    end
  end

  defp eatf_processor(module, type_id, {:type, _lineno, :tuple, type_params}, type_vars) do
    # Example:
    #   @type t_user_type_param(x, y) :: {integer(), x, y}
    #
    #   erlang abstract type format:
    #     {:type, 4, :tuple, [{:type, 4, :integer, []}, {:var, 4, :x}, {:var, 4, :y}]}
    #
    #   type_vars:
    #     [{:var, 4, :x}, {:var, 4, :y}]

    fn value, type_params_processors ->
      type_params_processors =
        type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)

      Types.tuple(value, type_params_processors)
    end
  end

  defp eatf_processor(_module, _type_id, {:type, _lineno, :map, []}, []) do
    # Example:
    #   @type t_empty_map :: %{}
    #
    #   erlang abstract type format:
    #     {:type, 36, :map, []}

    &Types.empty_map/2
  end

  defp eatf_processor(module, type_id, {:type, _lineno, :map, kv_type_params}, type_vars) do
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

    fn value, type_params_processors ->
      {value_rest, value_processed} =
        Enum.reduce(kv_required_type_params, {value, %{}}, fn
          {:type, _lineno, :map_field_exact, type_params}, {value_rest, value_processed} ->
            type_params = type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)
            {value_rest, value_processed_new} = Types.map_field_required(value_rest, type_params)
            {value_rest, Map.merge(value_processed, value_processed_new)}
        end)

      {value_rest, value_processed} =
        Enum.reduce(kv_optional_type_params, {value_rest, value_processed}, fn
          {:type, _lineno, :map_field_assoc, type_params}, {value_rest, value_processed} ->
            type_params = type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)
            {value_rest, value_processed_new} = Types.map_field_optional(value_rest, type_params)
            {value_rest, Map.merge(value_processed, value_processed_new)}
        end)

      if value_rest == %{} do
        value_processed
      else
        raise Error, "can't convert #{inspect(value)} to a map, bad k/v #{inspect(value_rest)}"
      end
    end
  end

  defp eatf_processor(module, _type_id, {:user_type, _lineno, type_id, type_params}, type_vars) do
    # Example:
    #   @type xxx :: t_user_type_param(integer(), integer())
    #
    #   erlang abstract type format:
    #     {:user_type, 6, :t_user_type_param, [{:type, 6, :integer, []}, {:type, 6, :integer, []}]}

    fn value, type_params_processors ->
      type_params_processors =
        type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars)

      type_parser = parser(module, type_id)
      type_parser.(value, type_params_processors)
    end
  end

  defp eatf_processor(module, type_id, eatf, type_params) do
    raise """
    Type processor not implemented:
    type=#{module}.#{type_id}
    erl_abstract_format=#{inspect(eatf)}\ntype_vars=#{inspect(type_params)}
    """
  end

  defp type_params_var_expansion(module, type_id, type_params, type_params_processors, type_vars) do
    if length(type_vars) != length(type_params_processors) do
      raise "Wrong number of type params for #{module}.#{type_id}/#{length(type_vars)}, got #{length(type_params_processors)}"
    end

    type_vars_2_processor =
      type_vars
      |> Enum.zip(type_params_processors)
      |> Map.new()

    Enum.map(type_params, fn
      {:var, _, _} = var -> Map.fetch!(type_vars_2_processor, var)
      {literal_type, 0, _literal} = eatf -> eatf_processor(module, literal_type, eatf, [])
      {_, _, type_id, _} = eatf -> eatf_processor(module, type_id, eatf, [])
    end)
  end
end
