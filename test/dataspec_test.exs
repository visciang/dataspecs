defmodule Test.DataSpecs do
  use ExUnit.Case, async: true

  alias DataSpecs.Loader
  alias Test.DataSpecs.CustomLoader

  @types_module Test.DataSpecs.SampleType
  @types_struct_module Test.DataSpecs.SampleStructType
  @types_empty_struct_module Test.DataSpecs.EmptyStructType

  describe "Unknown" do
    test "module" do
      assert_raise RuntimeError, ~r/Can't fetch type specifications for module :unknown_module/, fn ->
        DataSpecs.load(:a, {:unknown_module, :t})
      end
    end

    test "type in module" do
      assert_raise RuntimeError, "Unknown type #{inspect(@types_module)}.this_type_does_not_exist/0", fn ->
        DataSpecs.load(:a, {@types_module, :this_type_does_not_exist})
      end
    end
  end

  describe "literal" do
    test "ok" do
      assert {:ok, :a} == DataSpecs.load(:a, {@types_module, :t_literal_atom})
      assert {:ok, 1} == DataSpecs.load(1, {@types_module, :t_literal_integer})
    end

    test "error" do
      reason = ["value :not_a doesn't match literal value :a"]
      assert {:error, ^reason} = DataSpecs.load(:not_a, {@types_module, :t_literal_atom})

      reason = ["can't convert \"not an atom\" to an existing atom"]
      assert {:error, ^reason} = DataSpecs.load("not an atom", {@types_module, :t_literal_atom})

      reason = ["can't convert :not_an_integer to an integer"]
      assert {:error, ^reason} = DataSpecs.load(:not_an_integer, {@types_module, :t_literal_integer})
    end
  end

  describe "any type" do
    test "any" do
      assert {:ok, {:test, 1, ["a", "b"], 1..2}} ==
               DataSpecs.load({:test, 1, ["a", "b"], 1..2}, {@types_module, :t_any})
    end

    test "term" do
      assert {:ok, {"a_term"}} == DataSpecs.load({"a_term"}, {@types_module, :t_term})
    end
  end

  describe "pid type" do
    test "ok" do
      assert {:ok, self()} == DataSpecs.load(self(), {@types_module, :t_pid})
    end

    test "error" do
      reason = ["can't convert 1 to a pid"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_pid})
    end
  end

  describe "atom type" do
    test "ok" do
      assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_atom})
    end

    test "error" do
      reason = ["can't convert \"this_is_a_non_existing_atom\" to an existing atom"]
      assert {:error, ^reason} = DataSpecs.load("this_is_a_non_existing_atom", {@types_module, :t_atom})
    end
  end

  describe "boolean type" do
    test "ok" do
      assert {:ok, true} == DataSpecs.load(true, {@types_module, :t_boolean})
    end

    test "error" do
      reason = ["can't convert 1 to a boolean"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_boolean})
    end
  end

  describe "binary type" do
    test "ok" do
      assert {:ok, "binary"} == DataSpecs.load("binary", {@types_module, :t_binary})
    end

    test "error" do
      reason = ["can't convert 1 to a binary"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_binary})
    end
  end

  describe "bitstring type" do
    test "ok" do
      assert {:ok, <<>>} == DataSpecs.load(<<>>, {@types_module, :t_empty_bitstring})
      assert {:ok, <<1::1>>} == DataSpecs.load(<<1::1>>, {@types_module, :t_bitstring})
      assert {:ok, <<1::4>>} == DataSpecs.load(<<1::4>>, {@types_module, :t_bitstring_0})
      assert {:ok, <<1::12>>} == DataSpecs.load(<<1::12>>, {@types_module, :t_bitstring_1})
      assert {:ok, <<1, 2, 2::4>>} == DataSpecs.load(<<1, 2, 2::4>>, {@types_module, :t_bitstring_2})
    end

    test "error" do
      reason = ["can't convert 1 to a bitstring"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_bitstring})

      reason = ["can't convert <<1>> to a <<>>"]
      assert {:error, ^reason} = DataSpecs.load(<<1>>, {@types_module, :t_empty_bitstring})

      reason = ["can't convert <<1::size(5)>> to a <<_::0, _::_*4>>"]
      assert {:error, ^reason} = DataSpecs.load(<<1::5>>, {@types_module, :t_bitstring_1})
    end
  end

  describe "byte type" do
    test "ok" do
      assert {:ok, 0} == DataSpecs.load(0, {@types_module, :t_byte})
      assert {:ok, 128} == DataSpecs.load(128, {@types_module, :t_byte})
      assert {:ok, 255} == DataSpecs.load(255, {@types_module, :t_byte})
    end

    test "error" do
      reason = ["can't convert 256 to a byte"]
      assert {:error, ^reason} = DataSpecs.load(256, {@types_module, :t_byte})
    end
  end

  describe "char type" do
    test "ok" do
      assert {:ok, 0} == DataSpecs.load(0, {@types_module, :t_char})
      assert {:ok, 128} == DataSpecs.load(128, {@types_module, :t_char})
      assert {:ok, 0x10FFFF} == DataSpecs.load(0x10FFFF, {@types_module, :t_char})
    end

    test "error" do
      reason = ["can't convert #{0x110000} to a char"]
      assert {:error, ^reason} = DataSpecs.load(0x110000, {@types_module, :t_char})
    end
  end

  describe "arity type" do
    test "ok" do
      assert {:ok, 0} == DataSpecs.load(0, {@types_module, :t_arity})
      assert {:ok, 128} == DataSpecs.load(128, {@types_module, :t_arity})
      assert {:ok, 255} == DataSpecs.load(255, {@types_module, :t_arity})
    end

    test "error" do
      reason = ["can't convert 256 to a arity"]
      assert {:error, ^reason} = DataSpecs.load(256, {@types_module, :t_arity})
    end
  end

  describe "reference type" do
    test "ok" do
      ref = make_ref()
      assert {:ok, ref} == DataSpecs.load(ref, {@types_module, :t_reference})
    end

    test "error" do
      reason = ["can't convert 1 to a reference"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_reference})
    end
  end

  describe "number type" do
    test "ok" do
      assert {:ok, 123} == DataSpecs.load(123, {@types_module, :t_number})
      assert {:ok, 123.1} == DataSpecs.load(123.1, {@types_module, :t_number})
    end

    test "error" do
      reason = ["can't convert :a to a number"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_number})
    end
  end

  describe "float type" do
    test "ok" do
      assert {:ok, 123} == DataSpecs.load(123, {@types_module, :t_float})
      assert {:ok, 123.1} == DataSpecs.load(123.1, {@types_module, :t_float})
    end

    test "error" do
      reason = ["can't convert :a to a float"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_float})
    end
  end

  describe "integer type" do
    test "ok" do
      assert {:ok, 123} == DataSpecs.load(123, {@types_module, :t_integer})
      assert {:ok, -123} == DataSpecs.load(-123, {@types_module, :t_neg_integer})
      assert {:ok, 0} == DataSpecs.load(0, {@types_module, :t_non_neg_integer})
      assert {:ok, 123} == DataSpecs.load(123, {@types_module, :t_pos_integer})
    end

    test "error" do
      reason = ["can't convert :a to an integer"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_integer})

      reason = ["can't convert :a to a neg_integer"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_neg_integer})

      reason = ["can't convert :a to a non_neg_integer"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_non_neg_integer})

      reason = ["can't convert :a to a pos_integer"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_pos_integer})

      reason = ["can't convert 1 to a neg_integer"]
      assert {:error, ^reason} = DataSpecs.load(1, {@types_module, :t_neg_integer})

      reason = ["can't convert -1 to a non_neg_integer"]
      assert {:error, ^reason} = DataSpecs.load(-1, {@types_module, :t_non_neg_integer})

      reason = ["can't convert 0 to a pos_integer"]
      assert {:error, ^reason} = DataSpecs.load(0, {@types_module, :t_pos_integer})
    end
  end

  describe "range type" do
    test "ok" do
      assert {:ok, 5} == DataSpecs.load(5, {@types_module, :t_range})
      assert {:error, _} = DataSpecs.load(:a, {@types_module, :t_range})
    end

    test "error" do
      reason = ["can't convert 0 to a range 1..10"]
      assert {:error, ^reason} = DataSpecs.load(0, {@types_module, :t_range})
    end
  end

  describe "union type" do
    test "ok" do
      float = &Loader.Builtin.float/3
      assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, 1} == DataSpecs.load(1, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, 1.1} == DataSpecs.load(1.1, {@types_module, :t_union_0}, %{}, [float])
      assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_union_1})
      assert {:ok, {0, 1, 2}} == DataSpecs.load({0, 1, 2}, {@types_module, :t_union_1})
      assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_union_1})
    end

    test "error" do
      reason = [
        "can't convert %{} to a union",
        ["can't convert %{} to a tuple", "can't convert %{} to an atom", "can't convert %{} to an integer"]
      ]

      assert {:error, ^reason} = DataSpecs.load(%{}, {@types_module, :t_union_1})
    end
  end

  describe "list type" do
    test "ok" do
      integer = &Loader.Builtin.integer/3
      assert {:ok, []} == DataSpecs.load([], {@types_module, :t_empty_list})
      assert {:ok, [:a, :b]} == DataSpecs.load([:a, :b], {@types_module, :t_list})
      assert {:ok, [1, 2]} == DataSpecs.load([1, 2], {@types_module, :t_list_param}, %{}, [integer])
      assert {:ok, [1, :a]} == DataSpecs.load([1, :a], {@types_module, :t_nonempty_list_0})
      assert {:ok, [:a, :b]} == DataSpecs.load([:a, :b], {@types_module, :t_nonempty_list_1})
      assert {:ok, [:a, 1]} == DataSpecs.load([:a, 1], {@types_module, :t_list_of_any})
    end

    test "error" do
      reason = ["can't convert :a to a list"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_list})

      reason = ["can't convert [:a, 1] to a list, bad item at index=1", ["can't convert 1 to an atom"]]
      assert {:error, ^reason} = DataSpecs.load([:a, 1], {@types_module, :t_list})

      reason = ["can't convert [1] to an empty list"]
      assert {:error, ^reason} = DataSpecs.load([1], {@types_module, :t_empty_list})

      reason = ["can't convert [] to a non empty list"]
      assert {:error, ^reason} = DataSpecs.load([], {@types_module, :t_nonempty_list_0})

      reason = ["can't convert :not_a_list to a list"]
      assert {:error, ^reason} = DataSpecs.load(:not_a_list, {@types_module, :t_list_of_any})
    end
  end

  describe "keyword list type" do
    test "ok" do
      assert {:ok, [a: 1, b: :test]} == DataSpecs.load([a: 1, b: :test], {@types_module, :t_keyword_list})
    end

    test "error" do
      assert {:error, _} = DataSpecs.load([{:a, 1}, :bad], {@types_module, :t_keyword_list})
    end
  end

  describe "tuple type" do
    test "ok" do
      assert {:ok, {}} == DataSpecs.load({}, {@types_module, :t_empty_tuple})
      assert {:ok, {1, 2}} == DataSpecs.load({1, 2}, {@types_module, :t_tuple})
      assert {:ok, {1, 2}} == DataSpecs.load([1, 2], {@types_module, :t_tuple})
      assert {:ok, {1, "a"}} == DataSpecs.load({1, "a"}, {@types_module, :t_tuple_any_size})
    end

    test "error" do
      reason = ["can't convert nil to a tuple"]
      assert {:error, ^reason} = DataSpecs.load(nil, {@types_module, :t_tuple})

      reason = ["can't convert {:a, 2} to a tuple, bad item at index=0", ["can't convert :a to an integer"]]
      assert {:error, ^reason} = DataSpecs.load({:a, 2}, {@types_module, :t_tuple})

      reason = ["can't convert {1, 2, 3} to a tuple of size 2"]
      assert {:error, ^reason} = DataSpecs.load({1, 2, 3}, {@types_module, :t_tuple})

      reason = ["can't convert :not_a_tuple to a tuple"]
      assert {:error, ^reason} = DataSpecs.load(:not_a_tuple, {@types_module, :t_tuple_any_size})
    end
  end

  describe "map type" do
    test "ok" do
      integer = &Loader.Builtin.integer/3
      assert {:ok, %{}} == DataSpecs.load(%{}, {@types_module, :t_empty_map})
      assert {:ok, %{required_key: 1}} == DataSpecs.load(%{required_key: 1}, {@types_module, :t_map_0})
      assert {:ok, %{required_key: 1}} == DataSpecs.load(%{"required_key" => 1}, {@types_module, :t_map_0})
      assert {:ok, %{0 => :a}} == DataSpecs.load(%{0 => :a}, {@types_module, :t_map_1})
      assert {:ok, %{0 => :a}} == DataSpecs.load(%{0 => :a}, {@types_module, :t_map_2})
      assert {:ok, %{0 => :a, :b => 1}} == DataSpecs.load(%{0 => :a, :b => 1}, {@types_module, :t_map_3})

      assert {:ok, %{0 => %{a: true}, 1 => %{b: false}}} ==
               DataSpecs.load(%{0 => %{a: true}, 1 => %{b: false}}, {@types_module, :t_map_4})

      assert {:ok, %{0 => :a}} == DataSpecs.load(%{0 => :a}, {@types_module, :t_map_param}, %{}, [integer])
    end

    test "error" do
      reason = ["can't convert %{a: 1} to an empty map"]
      assert {:error, ^reason} = DataSpecs.load(%{a: 1}, {@types_module, :t_empty_map})

      reason = ["can't convert :foo to a map"]
      assert {:error, ^reason} = DataSpecs.load(:foo, {@types_module, :t_map_5})

      reason = ["can't convert :a to a map"]
      assert {:error, ^reason} = DataSpecs.load(:a, {@types_module, :t_map_0})

      reason = [
        "can't convert %{required_key_missing: 1} to a map, missing required k/v",
        ["value :required_key_missing doesn't match literal value :required_key"]
      ]

      assert {:error, ^reason} = DataSpecs.load(%{required_key_missing: 1}, {@types_module, :t_map_0})

      reason = ["can't convert %{b: 1} to a map, missing required k/v", ["can't convert :b to an integer"]]
      assert {:error, ^reason} = DataSpecs.load(%{:b => 1}, {@types_module, :t_map_3})

      reason = [
        "can't convert %{0 => :a, 1.1 => 1, :b => 1} to a map, bad k/v pairs: %{1.1 => 1}",
        ["can't convert 1.1 to an integer", "can't convert :b to an integer"]
      ]

      assert {:error, ^reason} = DataSpecs.load(%{0 => :a, :b => 1, 1.1 => 1}, {@types_module, :t_map_3})

      reason = [
        "can't convert %{0 => %{a: true}, 1 => %{b: \"not a bool\"}} to a map, bad k/v pairs: %{1 => %{b: \"not a bool\"}}",
        [
          "can't convert %{b: \"not a bool\"} to a map, missing required k/v",
          ["can't convert \"not a bool\" to a boolean"]
        ]
      ]

      assert {:error, ^reason} = DataSpecs.load(%{0 => %{a: true}, 1 => %{b: "not a bool"}}, {@types_module, :t_map_4})
    end
  end

  describe "struct type" do
    test "ok, load from map" do
      assert {:ok, %@types_struct_module{f_1: :a, f_2: 1, f_3: "s"}} ==
               @types_struct_module.load(%{f_1: :a, f_2: 1, f_3: "s"})

      assert {:ok, %@types_struct_module{f_1: :a, f_2: nil, f_3: nil}} ==
               @types_struct_module.load(%{f_1: :a})
    end

    test "ok, load from struct" do
      assert {:ok, %@types_struct_module{f_1: :a, f_2: nil, f_3: nil}} ==
               @types_struct_module.load(%@types_struct_module{f_1: :a})
    end

    test "ok, load empty struct" do
      assert {:ok, %@types_empty_struct_module{}} ==
               @types_empty_struct_module.load(%{})

      assert {:ok, %@types_empty_struct_module{}} ==
               @types_empty_struct_module.load(%@types_empty_struct_module{})
    end

    test "error" do
      reason = "the following keys must also be given when building struct #{inspect(@types_struct_module)}: [:f_1]"

      assert {:error, [^reason]} = @types_struct_module.load(%{})

      reason = [
        "can't convert %{f_1: \"not an atom\"} to a %#{inspect(@types_struct_module)}{} struct",
        ["can't convert %{f_1: \"not an atom\"} to a map, bad k/v pairs: %{f_1: \"not an atom\"}", []]
      ]

      assert {:error, ^reason} = @types_struct_module.load(%{f_1: "not an atom"})
    end
  end

  test "user type parametrized" do
    integer = &Loader.Builtin.integer/3
    assert {:ok, {0, 1, 2}} == DataSpecs.load({0, 1, 2}, {@types_module, :t_user_type_param_0})

    assert {:ok, {0, 1, 2}} ==
             DataSpecs.load({0, 1, 2}, {@types_module, :t_user_type_param_1}, %{}, [integer, integer])

    assert {:ok, 1} == DataSpecs.load(1, {@types_module, :t_user_type_param_2}, %{}, [integer])
  end

  test "same type name with different arities" do
    atom = &Loader.Builtin.atom/3
    assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_type_arity})
    assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_type_arity}, %{}, [atom])
  end

  test "remote type" do
    integer = &Loader.Builtin.integer/3
    assert {:ok, {1}} == DataSpecs.load({1}, {@types_module, :t_remote_type}, %{}, [integer])
    assert {:ok, {[true, false]}} == DataSpecs.load({[true, false]}, {@types_module, :t_remote_type}, %{}, [integer])
    assert {:ok, "string"} == DataSpecs.load("string", {@types_module, :t_remote_type_string})
  end

  test "recursive type" do
    assert {:ok, :test} == DataSpecs.load(:test, {@types_module, :t_recursive})
    assert {:ok, %{recursive: :test}} == DataSpecs.load(%{recursive: :test}, {@types_module, :t_recursive})

    assert {:ok, %{recursive: %{recursive: :test}}} ==
             DataSpecs.load(%{recursive: %{recursive: :test}}, {@types_module, :t_recursive})
  end

  describe "opaque type" do
    test "without custom type loader" do
      integer = &Loader.Builtin.integer/3

      reason = ["opaque type #{inspect(@types_module)}.t_opaque/1 has no custom type loader defined"]
      assert {:error, ^reason} = DataSpecs.load(:opaque, {@types_module, :t_opaque}, %{}, [integer])

      reason = ["opaque type Test.DataSpecs.SampleRemoteModuleType.t_opaque/1 has no custom type loader defined"]
      assert {:error, ^reason} = DataSpecs.load(:opaque, {@types_module, :t_remote_opaque})
    end

    test "with custom type loader" do
      integer = &Loader.Builtin.integer/3

      custom_type_loaders = %{
        {@types_module, :t_opaque, 1} => &CustomLoader.opaque/3,
        {MapSet, :t, 1} => &Loader.Extra.mapset/3
      }

      assert {:ok, {:custom_opaque, 1}} == DataSpecs.load(1, {@types_module, :t_opaque}, custom_type_loaders, [integer])

      assert {:ok, MapSet.new(1..3)} == DataSpecs.load(1..3, {@types_module, :t_mapset}, custom_type_loaders)

      assert {:ok, MapSet.new(["1", :a, 1])} ==
               DataSpecs.load(["1", :a, 1], {@types_module, :t_mapset_1}, custom_type_loaders)
    end
  end

  test "typep" do
    assert {:ok, :a} == DataSpecs.load(:a, {@types_module, :t_reference_to_private_type})
  end
end
