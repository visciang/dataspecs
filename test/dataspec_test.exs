defmodule Test.DataSpec do
  use ExUnit.Case

  alias DataSpec.{Error, Loaders}

  @types_module Test.DataSpec.SampleType
  @types_struct_module Test.DataSpec.SampleStructType

  test "unknown type in module" do
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :this_type_does_not_exist})
  end

  test "not implemented type loader" do
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :this_type_does_not_exist})
  end

  test "literal" do
    assert {:ok, :a} == DataSpec.load(:a, {@types_module, :t_literal_atom})
    assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_literal_integer})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_literal_atom})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_literal_integer})
  end

  test "any" do
    assert {:ok, {:test, 1, ["a", "b"], 1..2}} == DataSpec.load({:test, 1, ["a", "b"], 1..2}, {@types_module, :t_any})
  end

  test "term" do
    assert {:ok, {"a_term"}} == DataSpec.load({"a_term"}, {@types_module, :t_term})
  end

  test "pid" do
    assert {:ok, self()} == DataSpec.load(self(), {@types_module, :t_pid})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_pid})
  end

  test "atom" do
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_atom})
    assert {:error, %Error{}} = DataSpec.load("this_is_a_non_existing_atom", {@types_module, :t_atom})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_atom})
  end

  test "boolean" do
    assert {:ok, true} == DataSpec.load(true, {@types_module, :t_boolean})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_boolean})
  end

  test "binary" do
    assert {:ok, "binary"} == DataSpec.load("binary", {@types_module, :t_binary})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_binary})
  end

  test "reference" do
    ref = make_ref()
    assert {:ok, ref} == DataSpec.load(ref, {@types_module, :t_reference})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_reference})
  end

  test "number" do
    assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_number})
    assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_number})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_number})
  end

  test "float" do
    assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_float})
    assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_float})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_float})
  end

  test "integer" do
    assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_integer})
    assert {:ok, -123} == DataSpec.load(-123, {@types_module, :t_neg_integer})
    assert {:ok, 0} == DataSpec.load(0, {@types_module, :t_non_neg_integer})
    assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_pos_integer})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_integer})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_neg_integer})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_non_neg_integer})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_pos_integer})
    assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_neg_integer})
    assert {:error, %Error{}} = DataSpec.load(-1, {@types_module, :t_non_neg_integer})
    assert {:error, %Error{}} = DataSpec.load(0, {@types_module, :t_pos_integer})
  end

  test "range" do
    assert {:ok, 5} == DataSpec.load(5, {@types_module, :t_range})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_range})
    assert {:error, %Error{}} = DataSpec.load(0, {@types_module, :t_range})
  end

  test "union" do
    float = &Loaders.float/3
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_0}, %{}, [float])
    assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_union_0}, %{}, [float])
    assert {:ok, 1.1} == DataSpec.load(1.1, {@types_module, :t_union_0}, %{}, [float])
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_1})
    assert {:ok, {0, 1, 2}} == DataSpec.load({0, 1, 2}, {@types_module, :t_union_1})
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_1})
    assert {:error, %Error{}} = DataSpec.load(%{}, {@types_module, :t_union_1})
  end

  test "list" do
    integer = &Loaders.integer/3
    assert {:ok, []} == DataSpec.load([], {@types_module, :t_empty_list})
    assert {:ok, [:a, :b]} == DataSpec.load([:a, :b], {@types_module, :t_list})
    assert {:ok, [1, 2]} == DataSpec.load([1, 2], {@types_module, :t_list_param}, %{}, [integer])
    assert {:ok, [1, :a]} == DataSpec.load([1, :a], {@types_module, :t_nonempty_list_0})
    assert {:ok, [:a, :b]} == DataSpec.load([:a, :b], {@types_module, :t_nonempty_list_1})
    assert {:ok, [:a, 1]} == DataSpec.load([:a, 1], {@types_module, :t_list_of_any})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_list})
    assert {:error, %Error{}} = DataSpec.load([1], {@types_module, :t_list})
    assert {:error, %Error{}} = DataSpec.load([1], {@types_module, :t_empty_list})
    assert {:error, %Error{}} = DataSpec.load([], {@types_module, :t_nonempty_list_0})
    assert {:error, %Error{}} = DataSpec.load(:not_a_list, {@types_module, :t_list_of_any})
  end

  test "keyword list" do
    assert {:ok, [a: 1, b: :test]} == DataSpec.load([a: 1, b: :test], {@types_module, :t_keyword_list})
  end

  test "tuple" do
    assert {:ok, {}} == DataSpec.load({}, {@types_module, :t_tuple})
    assert {:ok, {1, 2}} == DataSpec.load({1, 2}, {@types_module, :t_tuple})
    assert {:ok, {1, "a"}} == DataSpec.load({1, "a"}, {@types_module, :t_tuple_any_size})
    assert {:error, %Error{}} = DataSpec.load(nil, {@types_module, :t_tuple})
    assert {:error, %Error{}} = DataSpec.load({:a, 2}, {@types_module, :t_tuple})
    assert {:error, %Error{}} = DataSpec.load(:not_a_tuple, {@types_module, :t_tuple_any_size})
  end

  test "map" do
    integer = &Loaders.integer/3
    assert {:ok, %{}} == DataSpec.load(%{}, {@types_module, :t_empty_map})
    assert {:ok, %{required_key: 1}} == DataSpec.load(%{required_key: 1}, {@types_module, :t_map_0})
    assert {:ok, %{required_key: 1}} == DataSpec.load(%{"required_key" => 1}, {@types_module, :t_map_0})
    assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_1})
    assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_2})
    assert {:ok, %{0 => :a, :b => 1}} == DataSpec.load(%{0 => :a, :b => 1}, {@types_module, :t_map_3})
    assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_param}, %{}, [integer])
    assert {:error, %Error{}} = DataSpec.load(%{a: 1}, {@types_module, :t_empty_map})
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_map_0})
    assert {:error, %Error{}} = DataSpec.load(%{:b => 1}, {@types_module, :t_map_3})
    assert {:error, %Error{}} = DataSpec.load(%{0 => :a, :b => 1, 1.1 => 1}, {@types_module, :t_map_3})
  end

  test "user type parametrized" do
    integer = &Loaders.integer/3
    assert {:ok, {0, 1, 2}} == DataSpec.load({0, 1, 2}, {@types_module, :t_user_type_param_0})
    assert {:ok, {0, 1, 2}} == DataSpec.load({0, 1, 2}, {@types_module, :t_user_type_param_1}, %{}, [integer, integer])
    assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_user_type_param_2}, %{}, [integer])
  end

  test "same type name with differnt arities" do
    atom = &Loaders.atom/3
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_arity})
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_arity}, %{}, [atom])
  end

  test "struct" do
    assert {:ok, %@types_struct_module{f_1: :a, f_2: 1, f_3: "s"}} ==
             DataSpec.load(%{f_1: :a, f_2: 1, f_3: "s"}, {@types_struct_module, :t})

    assert {:ok, %@types_struct_module{f_1: :a, f_2: nil, f_3: nil}} ==
             DataSpec.load(%{f_1: :a}, {@types_struct_module, :t})

    error_message = "the following keys must also be given when building struct Test.DataSpec.SampleStructType: [:f_1]"
    assert {:error, %DataSpec.Error{message: ^error_message}} = DataSpec.load(%{}, {@types_struct_module, :t})
  end

  test "remote type" do
    integer = &Loaders.integer/3
    assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_remote_type}, %{}, [integer])
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_remote_type}, %{}, [integer])
    assert {:ok, "string"} == DataSpec.load("string", {@types_module, :t_remote_type_string})
  end

  test "recursive type" do
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_recursive})
    assert {:ok, %{recursive: :test}} == DataSpec.load(%{recursive: :test}, {@types_module, :t_recursive})

    assert {:ok, %{recursive: %{recursive: :test}}} ==
             DataSpec.load(%{recursive: %{recursive: :test}}, {@types_module, :t_recursive})
  end

  test "opaque type without custom type loader" do
    integer = &Loaders.integer/3
    assert {:error, %Error{}} = DataSpec.load(:opaque, {@types_module, :t_opaque}, %{}, [integer])
    assert {:error, %Error{}} = DataSpec.load(:opaque, {@types_module, :t_mapset})
  end

  test "opaque type with custom type loader" do
    custom_type_loaders = %{
      {@types_module, :t_opaque, 1} => fn value, custom_type_loaders, [type_params_loader] ->
        {:custom_opaque, type_params_loader.(value, custom_type_loaders, [])}
      end,
      {MapSet, :t, 1} => fn value, custom_type_loaders, [type_params_loader] ->
        case Enumerable.impl_for(value) do
          nil ->
            raise Error, "can't convert #{inspect(value)} to a MapSet.t/1"

          _ ->
            MapSet.new(value, &type_params_loader.(&1, custom_type_loaders, []))
        end
      end,
      {DateTime, :t, 0} => fn value, _custom_type_loaders, [] ->
        with {:is_binary, true} <- {:is_binary, is_binary(value)},
             {:from_iso8601, {:ok, datetime, _}} <- {:from_iso8601, DateTime.from_iso8601(value)} do
          datetime
        else
          {:is_binary, false} ->
            raise Error, "can't convert #{inspect(value)} to a DateTime.t/0"

          {:from_iso8601, {:error, reason}} ->
            raise Error, "can't convert #{inspect(value)} to a DateTime.t/0 (#{inspect(reason)})"
        end
      end
    }

    integer = &Loaders.integer/3
    assert {:ok, {:custom_opaque, 1}} == DataSpec.load(1, {@types_module, :t_opaque}, custom_type_loaders, [integer])

    datetime = ~U[2021-07-14 20:22:49.653077Z]
    iso_datetime_string = DateTime.to_iso8601(datetime)
    assert {:ok, MapSet.new(1..3)} == DataSpec.load(1..3, {@types_module, :t_mapset}, custom_type_loaders)

    assert {:ok, MapSet.new(["1", :a, 1])} ==
             DataSpec.load(["1", :a, 1], {@types_module, :t_mapset_1}, custom_type_loaders)

    assert {:ok, datetime} == DataSpec.load(iso_datetime_string, {@types_module, :t_datetime}, custom_type_loaders)
  end

  test "typep" do
    assert {:ok, :a} == DataSpec.load(:a, {@types_module, :t_reference_to_private_type})
  end
end
