defmodule Test.DataSpec.SampleType do
  @type t_literal_atom :: :a
  @type t_literal_integer :: 1

  @type t_range :: 1..10

  @type t_any :: any()
  @type t_pid :: pid()
  @type t_reference :: reference()

  @type t_atom :: atom()

  @type t_float :: float()

  @type t_integer :: integer()
  @type t_neg_integer :: neg_integer()
  @type t_non_neg_integer :: non_neg_integer()
  @type t_pos_integer :: pos_integer()

  @type t_empty_list :: []
  @type t_list :: [atom()]
  @type t_list_param(x) :: [x]
  @type t_nonempty_list_0 :: [...]
  @type t_nonempty_list_1 :: [atom(), ...]

  @type t_keyword_list :: [a: integer(), b: atom()]

  @type t_empty_tuple :: {}
  @type t_tuple :: {integer(), integer()}

  @type t_empty_map :: %{}
  @type t_map_0 :: %{required_key: integer()}
  @type t_map_1 :: %{integer() => atom()}
  @type t_map_2 :: %{required(integer()) => atom()}
  @type t_map_3 :: %{required(integer()) => atom(), optional(atom()) => integer()}
  @type t_map_param(x) :: %{x => atom()}

  @type t_union_0(x) :: x | atom() | integer()
  @type t_union_1 :: t_union_0(t_user_type_param_0)

  @type t_user_type_param_0 :: t_user_type_param_1(integer(), integer())
  @type t_user_type_param_1(x, y) :: {integer(), x, y}
end
