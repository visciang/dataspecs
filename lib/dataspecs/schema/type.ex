defmodule DataSpecs.Schema.Type do
  @moduledoc """
  Type specifications' schema.

  Ref [Elixir Typespecs](https://hexdocs.pm/elixir/1.14.0/typespecs.html)
  """

  defmodule Literal do
    @moduledoc "A literal type."

    defmodule Atom do
      @moduledoc "Literal atom."

      @enforce_keys [:value]
      defstruct @enforce_keys

      @type t :: %__MODULE__{
              value: atom()
            }
    end

    defmodule Integer do
      @moduledoc "Literal integer."

      @enforce_keys [:value]
      defstruct @enforce_keys

      @type t :: %__MODULE__{
              value: integer()
            }
    end
  end

  defmodule Builtin do
    @moduledoc """
    A builtin type.
    """

    @enforce_keys [:id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id:
              :any
              | :pid
              | :reference
              | :atom
              | :boolean
              | :binary
              | :bitstring
              | :byte
              | :char
              | :arity
              | :number
              | :float
              | :integer
              | :neg_integer
              | :non_neg_integer
              | :pos_integer
          }
  end

  defmodule Bitstring do
    @moduledoc "Bit string."

    @enforce_keys [:size, :unit]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            size: non_neg_integer(),
            unit: non_neg_integer()
          }
  end

  defmodule Range do
    @moduledoc "Range."

    @enforce_keys [:lower, :upper]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            lower: integer(),
            upper: integer()
          }
  end

  defmodule Var do
    @moduledoc "Type variable."

    @enforce_keys [:id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id: atom()
          }
  end

  defmodule Union do
    @moduledoc "Union."

    @enforce_keys [:of]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            of: [DataSpecs.Schema.Type.t(), ...]
          }
  end

  defmodule List do
    @moduledoc "List."

    @type cardinality :: 0 | :* | :+

    @enforce_keys [:cardinality, :of]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            cardinality: cardinality(),
            of: DataSpecs.Schema.Type.type()
          }
  end

  defmodule Tuple do
    @moduledoc "Tuple."

    @type cardinality :: 0 | :* | pos_integer()

    @enforce_keys [:cardinality, :of]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            cardinality: cardinality(),
            of: [DataSpecs.Schema.Type.type()]
          }
  end

  defmodule Map do
    @moduledoc "Map."

    defmodule Key do
      @moduledoc "A map key."

      @enforce_keys [:required?, :type]
      defstruct @enforce_keys

      @type t :: %__MODULE__{
              required?: boolean(),
              type: DataSpecs.Schema.Type.type()
            }
    end

    @enforce_keys [:struct, :of]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            struct: nil | module(),
            of: [kv()]
          }

    @type kv :: {key :: Key.t(), value :: DataSpecs.Schema.Type.type()}
  end

  defmodule Ref do
    @moduledoc "Type reference (remote/user types)."

    @enforce_keys [:module, :id, :params]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            module: module(),
            id: atom(),
            params: [DataSpecs.Schema.Type.type()]
          }
  end

  defmodule Unsupported do
    @moduledoc "Unsupported type specs."

    @enforce_keys []
    defstruct @enforce_keys

    @type t :: %__MODULE__{}
  end

  @enforce_keys [:visibility, :module, :id, :vars, :type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          visibility: visibility(),
          module: module(),
          id: atom(),
          vars: [Var.t()],
          type: type()
        }

  @type visibility :: :type | :typep | :opaque

  @type type ::
          Literal.Atom.t()
          | Literal.Integer.t()
          | Builtin.t()
          | Bitstring.t()
          | Range.t()
          | Var.t()
          | Union.t()
          | List.t()
          | Tuple.t()
          | Map.t()
          | Ref.t()
          | Unsupported.t()

  @spec format_typeref(t()) :: String.t()
  def format_typeref(%__MODULE__{} = t) do
    "#{inspect(t.module)}.#{t.id}/#{length(t.vars)}"
  end

  # coveralls-ignore-start

  @doc false
  defmacro literal_types do
    quote do
      [:atom, :integer]
    end
  end

  # coveralls-ignore-stop

  # coveralls-ignore-start

  @doc false
  defmacro zero_arity_builtin_types do
    quote do
      [
        :any,
        :pid,
        :reference,
        :atom,
        :boolean,
        :binary,
        :bitstring,
        :byte,
        :char,
        :arity,
        :number,
        :float,
        :integer,
        :neg_integer,
        :non_neg_integer,
        :pos_integer
      ]
    end
  end
end

# coveralls-ignore-stop
