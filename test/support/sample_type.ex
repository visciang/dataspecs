defmodule Test.DataSpecs.SampleType do
  @moduledoc false

  @type t_literal_atom :: :a
  @type t_literal_integer :: 1

  @type t_range :: 1..10

  @type t_any :: any()
  @type t_term :: term()
  @type t_pid :: pid()
  @type t_reference :: reference()
  @type t_atom :: atom()
  @type t_boolean :: boolean()
  @type t_binary :: binary()
  @type t_byte :: byte()
  @type t_char :: char()
  @type t_arity :: arity()

  @type t_empty_bitstring :: <<>>
  @type t_bitstring :: bitstring()
  @type t_bitstring_0 :: <<_::4>>
  @type t_bitstring_1 :: <<_::_*4>>
  @type t_bitstring_2 :: <<_::16, _::_*4>>

  @type t_number :: number()
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
  @type t_list_of_any :: list()

  @type t_keyword_list :: [a: integer(), b: atom()]

  @type t_empty_tuple :: {}
  @type t_tuple :: {integer(), integer()}
  @type t_tuple_any_size :: tuple()

  @type t_empty_map :: %{}
  @type t_map_0 :: %{required_key: integer()}
  @type t_map_1 :: %{integer() => atom()}
  @type t_map_2 :: %{required(integer()) => atom()}
  @type t_map_3 :: %{required(integer()) => atom(), optional(atom()) => integer()}
  @type t_map_4 :: %{integer() => %{atom() => boolean()}}
  @type t_map_param(x) :: %{x => atom()}

  @type t_union_0(x) :: x | atom() | integer()
  @type t_union_1 :: t_union_0(t_user_type_param_0)

  @type t_user_type_param_0 :: t_user_type_param_1(integer(), integer())
  @type t_user_type_param_1(x, y) :: {integer(), x, y}
  @type t_user_type_param_2(x) :: x

  @type t_type_arity :: atom()
  @type t_type_arity(x) :: x

  @type t_remote_type(x) :: Test.DataSpecs.SampleRemoteModuleType.t_remote(x)
  @type t_remote_type_string :: String.t()
  @type t_mapset :: MapSet.t(integer())
  @type t_mapset_1 :: MapSet.t(t_union_0(binary()))
  @type t_datetime :: DateTime.t()

  @type t_recursive :: atom() | %{recursive: t_recursive()}

  @type t_reference_to_private_type :: t_private()
  @typep t_private() :: atom()

  @opaque t_opaque(x) :: {x, float()}

  # CURRENTLY NOT IMPLEMENTED TYPES
  # @type t_fun :: (integer() -> integer())
  # @type t_identifier :: identifier()
  # @type t_iodata :: iodata()
  # @type t_iolist :: iolist()
  # @type t_maybe_improper_list :: maybe_improper_list()
  # @type t_nonempty_maybe_improper_list :: nonempty_maybe_improper_list()
  # @type t_mfa :: mfa()
  # @type t_module :: module()
  # @type t_node :: node()
  # @type t_timeout :: timeout()
end

defmodule Test.DataSpecs.SampleRemoteModuleType do
  @moduledoc false

  @type t_remote(x) :: x | atom()
end

defmodule Test.DataSpecs.SampleStructType do
  @moduledoc false

  use DataSpecs

  @enforce_keys [:f_1]
  defstruct [:f_1, :f_2, :f_3]

  @type t :: %__MODULE__{
          f_1: atom(),
          f_2: nil | integer(),
          f_3: nil | String.t()
        }
end
