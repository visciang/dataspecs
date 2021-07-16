defmodule Test.DataSpec do
  use ExUnit.Case

  alias DataSpec.{Error, Loaders}
  alias Test.DataSpec.CustomLoader

  @types_module Test.DataSpec.SampleType
  @types_struct_module Test.DataSpec.SampleStructType

  test "unknown type in module" do
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :this_type_does_not_exist})
  end

  test "not implemented type loader" do
    assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :this_type_does_not_exist})
  end

  describe "literal" do
    test "ok" do
      assert {:ok, :a} == DataSpec.load(:a, {@types_module, :t_literal_atom})
      assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_literal_integer})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_literal_atom})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_literal_integer})
    end
  end

  describe "any type" do
    test "any" do
      assert {:ok, {:test, 1, ["a", "b"], 1..2}} == DataSpec.load({:test, 1, ["a", "b"], 1..2}, {@types_module, :t_any})
    end

    test "term" do
      assert {:ok, {"a_term"}} == DataSpec.load({"a_term"}, {@types_module, :t_term})
    end
  end

  describe "pid" do
    test "ok" do
      assert {:ok, self()} == DataSpec.load(self(), {@types_module, :t_pid})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_pid})
    end
  end

  describe "atom" do
    test "ok" do
      assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_atom})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load("this_is_a_non_existing_atom", {@types_module, :t_atom})
    end
  end

  describe "boolean" do
    test "ok" do
      assert {:ok, true} == DataSpec.load(true, {@types_module, :t_boolean})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_boolean})
    end
  end

  describe "binary" do
    test "ok" do
      assert {:ok, "binary"} == DataSpec.load("binary", {@types_module, :t_binary})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_binary})
    end
  end

  describe "reference" do
    test "ok" do
      ref = make_ref()
      assert {:ok, ref} == DataSpec.load(ref, {@types_module, :t_reference})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_reference})
    end
  end

  describe "number" do
    test "ok" do
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_number})
      assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_number})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_number})
    end
  end

  describe "float" do
    test "ok" do
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_float})
      assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_float})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_float})
    end
  end

  describe "integer" do
    test "ok" do
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_integer})
      assert {:ok, -123} == DataSpec.load(-123, {@types_module, :t_neg_integer})
      assert {:ok, 0} == DataSpec.load(0, {@types_module, :t_non_neg_integer})
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_pos_integer})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_integer})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_neg_integer})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_non_neg_integer})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_pos_integer})
      assert {:error, %Error{}} = DataSpec.load(1, {@types_module, :t_neg_integer})
      assert {:error, %Error{}} = DataSpec.load(-1, {@types_module, :t_non_neg_integer})
      assert {:error, %Error{}} = DataSpec.load(0, {@types_module, :t_pos_integer})
    end
  end

  describe "range" do
    test "ok" do
      assert {:ok, 5} == DataSpec.load(5, {@types_module, :t_range})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_range})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(0, {@types_module, :t_range})
    end
  end

  describe "union" do
    test "ok" do
      float = &Loaders.float/3
      assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, 1.1} == DataSpec.load(1.1, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_1})
      assert {:ok, {0, 1, 2}} == DataSpec.load({0, 1, 2}, {@types_module, :t_union_1})
      assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_union_1})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(%{}, {@types_module, :t_union_1})
    end
  end

  describe "list" do
    test "ok" do
      integer = &Loaders.integer/3
      assert {:ok, []} == DataSpec.load([], {@types_module, :t_empty_list})
      assert {:ok, [:a, :b]} == DataSpec.load([:a, :b], {@types_module, :t_list})
      assert {:ok, [1, 2]} == DataSpec.load([1, 2], {@types_module, :t_list_param}, %{}, [integer])
      assert {:ok, [1, :a]} == DataSpec.load([1, :a], {@types_module, :t_nonempty_list_0})
      assert {:ok, [:a, :b]} == DataSpec.load([:a, :b], {@types_module, :t_nonempty_list_1})
      assert {:ok, [:a, 1]} == DataSpec.load([:a, 1], {@types_module, :t_list_of_any})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_list})
      assert {:error, %Error{}} = DataSpec.load([1], {@types_module, :t_list})
      assert {:error, %Error{}} = DataSpec.load([1], {@types_module, :t_empty_list})
      assert {:error, %Error{}} = DataSpec.load([], {@types_module, :t_nonempty_list_0})
      assert {:error, %Error{}} = DataSpec.load(:not_a_list, {@types_module, :t_list_of_any})
    end
  end

  describe "keyword list" do
    test "ok" do
      assert {:ok, [a: 1, b: :test]} == DataSpec.load([a: 1, b: :test], {@types_module, :t_keyword_list})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load([{:a, 1}, :bad], {@types_module, :t_keyword_list})
    end
  end

  describe "tuple" do
    test "ok" do
      assert {:ok, {}} == DataSpec.load({}, {@types_module, :t_empty_tuple})
      assert {:ok, {1, 2}} == DataSpec.load({1, 2}, {@types_module, :t_tuple})
      assert {:ok, {1, "a"}} == DataSpec.load({1, "a"}, {@types_module, :t_tuple_any_size})
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(nil, {@types_module, :t_tuple})
      assert {:error, %Error{}} = DataSpec.load({:a, 2}, {@types_module, :t_tuple})
      assert {:error, %Error{}} = DataSpec.load({1, 2, 3}, {@types_module, :t_tuple})
      assert {:error, %Error{}} = DataSpec.load(:not_a_tuple, {@types_module, :t_tuple_any_size})
    end
  end

  describe "map" do
    test "ok" do
      integer = &Loaders.integer/3
      assert {:ok, %{}} == DataSpec.load(%{}, {@types_module, :t_empty_map})
      assert {:ok, %{required_key: 1}} == DataSpec.load(%{required_key: 1}, {@types_module, :t_map_0})
      assert {:ok, %{required_key: 1}} == DataSpec.load(%{"required_key" => 1}, {@types_module, :t_map_0})
      assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_1})
      assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_2})
      assert {:ok, %{0 => :a, :b => 1}} == DataSpec.load(%{0 => :a, :b => 1}, {@types_module, :t_map_3})

      assert {:ok, %{0 => %{a: true}, 1 => %{b: false}}} ==
               DataSpec.load(%{0 => %{a: true}, 1 => %{b: false}}, {@types_module, :t_map_4})

      assert {:ok, %{0 => :a}} == DataSpec.load(%{0 => :a}, {@types_module, :t_map_param}, %{}, [integer])
    end

    test "error" do
      assert {:error, %Error{}} = DataSpec.load(%{a: 1}, {@types_module, :t_empty_map})
      assert {:error, %Error{}} = DataSpec.load(:a, {@types_module, :t_map_0})
      assert {:error, %Error{}} = DataSpec.load(%{:b => 1}, {@types_module, :t_map_3})
      assert {:error, %Error{}} = DataSpec.load(%{0 => :a, :b => 1, 1.1 => 1}, {@types_module, :t_map_3})
    end
  end

  test "user type parametrized" do
    integer = &Loaders.integer/3
    assert {:ok, {0, 1, 2}} == DataSpec.load({0, 1, 2}, {@types_module, :t_user_type_param_0})

    assert {:ok, {0, 1, 2}} ==
             DataSpec.load({0, 1, 2}, {@types_module, :t_user_type_param_1}, %{}, [integer, integer])

    assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_user_type_param_2}, %{}, [integer])
  end

  test "same type name with different arities" do
    atom = &Loaders.atom/3
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_type_arity})
    assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_type_arity}, %{}, [atom])
  end

  describe "struct" do
    test "ok" do
      assert {:ok, %@types_struct_module{f_1: :a, f_2: 1, f_3: "s"}} ==
               DataSpec.load(%{f_1: :a, f_2: 1, f_3: "s"}, {@types_struct_module, :t})

      assert {:ok, %@types_struct_module{f_1: :a, f_2: nil, f_3: nil}} ==
               DataSpec.load(%{f_1: :a}, {@types_struct_module, :t})
    end

    test "error" do
      error_message =
        "the following keys must also be given when building struct Test.DataSpec.SampleStructType: [:f_1]"

      assert {:error, %DataSpec.Error{message: ^error_message}} = DataSpec.load(%{}, {@types_struct_module, :t})
    end
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

  describe "opaque type" do
    test "without custom type loader" do
      integer = &Loaders.integer/3
      assert {:error, %Error{}} = DataSpec.load(:opaque, {@types_module, :t_opaque}, %{}, [integer])
      assert {:error, %Error{}} = DataSpec.load(:opaque, {@types_module, :t_mapset})
    end

    test "with custom type loader" do
      integer = &Loaders.integer/3

      custom_type_loaders = %{
        {@types_module, :t_opaque, 1} => &CustomLoader.opaque/3,
        {MapSet, :t, 1} => &CustomLoader.mapset/3,
        {DateTime, :t, 0} => &CustomLoader.isodatetime/3
      }

      assert {:ok, {:custom_opaque, 1}} == DataSpec.load(1, {@types_module, :t_opaque}, custom_type_loaders, [integer])

      datetime = ~U[2021-07-14 20:22:49.653077Z]
      iso_datetime_string = DateTime.to_iso8601(datetime)
      assert {:ok, MapSet.new(1..3)} == DataSpec.load(1..3, {@types_module, :t_mapset}, custom_type_loaders)

      assert {:ok, MapSet.new(["1", :a, 1])} ==
               DataSpec.load(["1", :a, 1], {@types_module, :t_mapset_1}, custom_type_loaders)

      assert {:ok, datetime} == DataSpec.load(iso_datetime_string, {@types_module, :t_datetime}, custom_type_loaders)
    end
  end

  test "typep" do
    assert {:ok, :a} == DataSpec.load(:a, {@types_module, :t_reference_to_private_type})
  end
end

defmodule Test.DataSpec.CustomLoader do
  alias DataSpec.Error

  def opaque(value, custom_type_loaders, [type_params_loader]) do
    {:custom_opaque, type_params_loader.(value, custom_type_loaders, [])}
  end

  def mapset(value, custom_type_loaders, [type_params_loader]) do
    case Enumerable.impl_for(value) do
      nil ->
        raise Error, "can't convert #{inspect(value)} to a MapSet.t/1"

      _ ->
        MapSet.new(value, &type_params_loader.(&1, custom_type_loaders, []))
    end
  end

  def isodatetime(value, _custom_type_loaders, []) do
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
end
