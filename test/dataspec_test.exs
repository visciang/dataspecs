defmodule Test.DataSpec do
  use ExUnit.Case

  alias DataSpec.Loaders
  alias Test.DataSpec.CustomLoader

  @types_module Test.DataSpec.SampleType
  @types_struct_module Test.DataSpec.SampleStructType

  describe "Unknown" do
    test "module" do
      assert_raise RuntimeError, "Can't fetch type specifications for module :unknown_module", fn ->
        DataSpec.load(:a, {:unknown_module, :t})
      end
    end

    test "type in module" do
      assert_raise RuntimeError, "Unknown type #{inspect(@types_module)}.this_type_does_not_exist/0", fn ->
        DataSpec.load(:a, {@types_module, :this_type_does_not_exist})
      end
    end
  end

  describe "literal" do
    test "ok" do
      assert {:ok, :a} == DataSpec.load(:a, {@types_module, :t_literal_atom})
      assert {:ok, 1} == DataSpec.load(1, {@types_module, :t_literal_integer})
    end

    test "error" do
      reason = ["value :not_a doesn't match literal value :a"]
      assert {:error, ^reason} = DataSpec.load(:not_a, {@types_module, :t_literal_atom})

      reason = ["can't convert \"not an atom\" to an existing atom"]
      assert {:error, ^reason} = DataSpec.load("not an atom", {@types_module, :t_literal_atom})

      reason = ["can't convert :not_an_integer to an integer"]
      assert {:error, ^reason} = DataSpec.load(:not_an_integer, {@types_module, :t_literal_integer})
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
      reason = ["can't convert 1 to a pid"]
      assert {:error, ^reason} = DataSpec.load(1, {@types_module, :t_pid})
    end
  end

  describe "atom" do
    test "ok" do
      assert {:ok, :test} == DataSpec.load(:test, {@types_module, :t_atom})
    end

    test "error" do
      reason = ["can't convert \"this_is_a_non_existing_atom\" to an existing atom"]
      assert {:error, ^reason} = DataSpec.load("this_is_a_non_existing_atom", {@types_module, :t_atom})
    end
  end

  describe "boolean" do
    test "ok" do
      assert {:ok, true} == DataSpec.load(true, {@types_module, :t_boolean})
    end

    test "error" do
      reason = ["can't convert 1 to a boolean"]
      assert {:error, ^reason} = DataSpec.load(1, {@types_module, :t_boolean})
    end
  end

  describe "binary" do
    test "ok" do
      assert {:ok, "binary"} == DataSpec.load("binary", {@types_module, :t_binary})
    end

    test "error" do
      reason = ["can't convert 1 to a binary"]
      assert {:error, ^reason} = DataSpec.load(1, {@types_module, :t_binary})
    end
  end

  describe "reference" do
    test "ok" do
      ref = make_ref()
      assert {:ok, ref} == DataSpec.load(ref, {@types_module, :t_reference})
    end

    test "error" do
      reason = ["can't convert 1 to a reference"]
      assert {:error, ^reason} = DataSpec.load(1, {@types_module, :t_reference})
    end
  end

  describe "number" do
    test "ok" do
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_number})
      assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_number})
    end

    test "error" do
      reason = ["can't convert :a to a number"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_number})
    end
  end

  describe "float" do
    test "ok" do
      assert {:ok, 123} == DataSpec.load(123, {@types_module, :t_float})
      assert {:ok, 123.1} == DataSpec.load(123.1, {@types_module, :t_float})
    end

    test "error" do
      reason = ["can't convert :a to a float"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_float})
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
      reason = ["can't convert :a to an integer"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_integer})

      reason = ["can't convert :a to a neg_integer"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_neg_integer})

      reason = ["can't convert :a to a non_neg_integer"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_non_neg_integer})

      reason = ["can't convert :a to a pos_integer"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_pos_integer})

      reason = ["can't convert 1 to a neg_integer"]
      assert {:error, ^reason} = DataSpec.load(1, {@types_module, :t_neg_integer})

      reason = ["can't convert -1 to a non_neg_integer"]
      assert {:error, ^reason} = DataSpec.load(-1, {@types_module, :t_non_neg_integer})

      reason = ["can't convert 0 to a pos_integer"]
      assert {:error, ^reason} = DataSpec.load(0, {@types_module, :t_pos_integer})
    end
  end

  describe "range" do
    test "ok" do
      assert {:ok, 5} == DataSpec.load(5, {@types_module, :t_range})
      assert {:error, _} = DataSpec.load(:a, {@types_module, :t_range})
    end

    test "error" do
      reason = ["can't convert 0 to a range 1..10"]
      assert {:error, ^reason} = DataSpec.load(0, {@types_module, :t_range})
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
      reason = [
        "can't convert %{} to a union",
        ["can't convert %{} to a tuple", "can't convert %{} to an atom", "can't convert %{} to an integer"]
      ]

      assert {:error, ^reason} = DataSpec.load(%{}, {@types_module, :t_union_1})
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
      reason = ["can't convert :a to a list"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_list})

      reason = ["can't convert [:a, 1] to a list, bad item at index=1", ["can't convert 1 to an atom"]]
      assert {:error, ^reason} = DataSpec.load([:a, 1], {@types_module, :t_list})

      reason = ["can't convert [1] to an empty list"]
      assert {:error, ^reason} = DataSpec.load([1], {@types_module, :t_empty_list})

      reason = ["can't convert [] to a non empty list"]
      assert {:error, ^reason} = DataSpec.load([], {@types_module, :t_nonempty_list_0})

      reason = ["can't convert :not_a_list to a list"]
      assert {:error, ^reason} = DataSpec.load(:not_a_list, {@types_module, :t_list_of_any})
    end
  end

  describe "keyword list" do
    test "ok" do
      assert {:ok, [a: 1, b: :test]} == DataSpec.load([a: 1, b: :test], {@types_module, :t_keyword_list})
    end

    test "error" do
      assert {:error, _} = DataSpec.load([{:a, 1}, :bad], {@types_module, :t_keyword_list})
    end
  end

  describe "tuple" do
    test "ok" do
      assert {:ok, {}} == DataSpec.load({}, {@types_module, :t_empty_tuple})
      assert {:ok, {1, 2}} == DataSpec.load({1, 2}, {@types_module, :t_tuple})
      assert {:ok, {1, "a"}} == DataSpec.load({1, "a"}, {@types_module, :t_tuple_any_size})
    end

    test "error" do
      reason = ["can't convert nil to a tuple"]
      assert {:error, ^reason} = DataSpec.load(nil, {@types_module, :t_tuple})

      reason = ["can't convert {:a, 2} to a tuple, bad item at index=0", ["can't convert :a to an integer"]]
      assert {:error, ^reason} = DataSpec.load({:a, 2}, {@types_module, :t_tuple})

      reason = ["can't convert {1, 2, 3} to a tuple of size 2"]
      assert {:error, ^reason} = DataSpec.load({1, 2, 3}, {@types_module, :t_tuple})

      reason = ["can't convert :not_a_tuple to a tuple"]
      assert {:error, ^reason} = DataSpec.load(:not_a_tuple, {@types_module, :t_tuple_any_size})
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
      reason = ["can't convert %{a: 1} to an empty map"]
      assert {:error, ^reason} = DataSpec.load(%{a: 1}, {@types_module, :t_empty_map})

      reason = ["can't convert :a to a map"]
      assert {:error, ^reason} = DataSpec.load(:a, {@types_module, :t_map_0})

      reason = [
        "can't convert %{required_key_missing: 1} to a map, missing required k/v",
        ["value :required_key_missing doesn't match literal value :required_key"]
      ]

      assert {:error, ^reason} = DataSpec.load(%{required_key_missing: 1}, {@types_module, :t_map_0})

      reason = ["can't convert %{b: 1} to a map, missing required k/v", ["can't convert :b to an integer"]]
      assert {:error, ^reason} = DataSpec.load(%{:b => 1}, {@types_module, :t_map_3})

      reason = [
        "can't convert %{0 => :a, 1.1 => 1, :b => 1} to a map, bad k/v pairs: %{1.1 => 1}",
        ["can't convert 1.1 to an integer", "can't convert :b to an integer"]
      ]

      assert {:error, ^reason} = DataSpec.load(%{0 => :a, :b => 1, 1.1 => 1}, {@types_module, :t_map_3})

      reason = [
        "can't convert %{0 => %{a: true}, 1 => %{b: \"not a bool\"}} to a map, bad k/v pairs: %{1 => %{b: \"not a bool\"}}",
        [
          "can't convert %{b: \"not a bool\"} to a map, missing required k/v",
          ["can't convert \"not a bool\" to a boolean"]
        ]
      ]

      assert {:error, ^reason} = DataSpec.load(%{0 => %{a: true}, 1 => %{b: "not a bool"}}, {@types_module, :t_map_4})
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

      assert {:ok, %@types_struct_module{f_1: :a, f_2: nil, f_3: nil}} ==
               DataSpec.load(%@types_struct_module{f_1: :a}, {@types_struct_module, :t})
    end

    test "error" do
      reason = "the following keys must also be given when building struct #{inspect(@types_struct_module)}: [:f_1]"

      assert {:error, [^reason]} = DataSpec.load(%{}, {@types_struct_module, :t})

      reason = [
        "can't convert %{f_1: \"not an atom\"} to a %#{inspect(@types_struct_module)}{} struct",
        ["can't convert %{f_1: \"not an atom\"} to a map, bad k/v pairs: %{f_1: \"not an atom\"}", []]
      ]

      assert {:error, ^reason} = DataSpec.load(%{f_1: "not an atom"}, {@types_struct_module, :t})
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

      reason = ["opaque type #{inspect(@types_module)}.t_opaque/1 has no custom type loader defined"]
      assert {:error, ^reason} = DataSpec.load(:opaque, {@types_module, :t_opaque}, %{}, [integer])

      reason = ["opaque type MapSet.t/1 has no custom type loader defined"]
      assert {:error, ^reason} = DataSpec.load(:opaque, {@types_module, :t_mapset})
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
  alias DataSpec.Loaders

  def opaque(value, custom_type_loaders, [type_params_loader]) do
    type_params_loader.(value, custom_type_loaders, [])
    |> case do
      {:ok, loaded_value} ->
        {:ok, {:custom_opaque, loaded_value}}

      {:error, _} = error ->
        error
    end
  end

  def mapset(value, custom_type_loaders, [type_params_loader]) do
    case Enumerable.impl_for(value) do
      nil ->
        {:error, ["can't convert #{inspect(value)} to a MapSet.t/1, value not enumerable"]}

      _ ->
        value
        |> Enum.to_list()
        |> Loaders.list(custom_type_loaders, [type_params_loader])
        |> case do
          {:ok, loaded_value} ->
            {:ok, MapSet.new(loaded_value)}

          {:error, errors} ->
            {:error, ["can't convert #{inspect(value)} to a MapSet.t/1", errors]}
        end
    end
  end

  def isodatetime(value, _custom_type_loaders, []) do
    with {:is_binary, true} <- {:is_binary, is_binary(value)},
         {:from_iso8601, {:ok, datetime, _}} <- {:from_iso8601, DateTime.from_iso8601(value)} do
      {:ok, datetime}
    else
      {:is_binary, false} ->
        {:error, ["can't convert #{inspect(value)} to a DateTime.t/0"]}

      {:from_iso8601, {:error, reason}} ->
        {:error, ["can't convert #{inspect(value)} to a DateTime.t/0 (#{inspect(reason)})"]}
    end
  end
end
