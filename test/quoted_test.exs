defmodule Test.DataSpecs.Schema.Quoted do
  use ExUnit.Case, async: true

  alias DataSpecs.Schema

  @sample_type Test.DataSpecs.SampleType

  setup_all do
    schemas =
      @sample_type
      |> Schema.load()
      |> Map.new(fn %Schema.Type{} = t ->
        {{@sample_type, t.id, length(t.vars)}, t}
      end)

    [schemas: schemas]
  end

  test "literals", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_literal_atom, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_literal_atom() :: :a"

    schema = Map.fetch!(schemas, {@sample_type, :t_literal_integer, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_literal_integer() :: 1"
  end

  test "builtin", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_any, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_any() :: any()"
  end

  test "bitstring", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_empty_bitstring, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_empty_bitstring() :: <<>>"

    schema = Map.fetch!(schemas, {@sample_type, :t_bitstring_0, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_bitstring_0() :: <<_::4>>"

    schema = Map.fetch!(schemas, {@sample_type, :t_bitstring_1, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_bitstring_1() :: <<_::_*4>>"

    schema = Map.fetch!(schemas, {@sample_type, :t_bitstring_2, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_bitstring_2() :: <<_::16, _::_*4>>"
  end

  test "range", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_range, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_range() :: 1..10"
  end

  test "union", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_union_0, 1})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_union_0(x) :: x | atom() | integer()"
  end

  test "list", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_empty_list, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_empty_list() :: []"

    schema = Map.fetch!(schemas, {@sample_type, :t_list, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_list() :: [atom()]"

    schema = Map.fetch!(schemas, {@sample_type, :t_nonempty_list_0, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_nonempty_list_0() :: [any(), ...]"
  end

  test "tuple", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_empty_tuple, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_empty_tuple() :: {}"

    schema = Map.fetch!(schemas, {@sample_type, :t_tuple, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_tuple() :: {integer(), integer()}"

    schema = Map.fetch!(schemas, {@sample_type, :t_tuple_any_size, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_tuple_any_size() :: tuple()"
  end

  test "map", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_empty_map, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_empty_map() :: %{}"

    schema = Map.fetch!(schemas, {@sample_type, :t_map_0, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_map_0() :: %{required_key: integer()}"

    schema = Map.fetch!(schemas, {@sample_type, :t_map_5, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_map_5() :: %{optional(integer()) => atom()}"
  end

  test "ref", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_mapset, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_mapset() :: MapSet.t(integer())"
  end

  test "unsupported", %{schemas: schemas} do
    schema = Map.fetch!(schemas, {@sample_type, :t_unsupported, 0})

    assert Schema.Formatter.to_typespec_string(schema) ==
             "@type Test.DataSpecs.SampleType.t_unsupported() :: :__unsupported__"
  end
end
