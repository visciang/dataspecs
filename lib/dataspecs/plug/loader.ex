# coveralls-ignore-start

if Code.ensure_loaded?(Plug) do
  defmodule DataSpecs.Plug.Loader do
    @moduledoc """
    DataSpecs Plug

    NOTE: this module is available if you include the optional dependency ":plug".

    This module can be used to plug a "Jason.decode! -> DataSpecs.load" pipeline in your routes.

    For example:

      defmodule Api.Router.Something do
        use Plug.Router
        alias Splug.Api.Model
        import #{__MODULE__}, only: [typeref: 2, value: 1]

        plug :match
        plug #{__MODULE__}
        plug :dispatch

        post "/foo", typeref(Model.Foo, :t) do
          %Api.Model.Foo{...} = value(conn)
          ...
        end
      end

      defmodule Api.Model.Foo do
        defmodule Bar do
          @enforce_keys [:b1, :b2]
          defstruct [:b1, :b2]

          @type t :: %__MODULE__{
                  b1: nil | number(),
                  b2: String.t()
                }
        end

        @enforce_keys [:a]
        defstruct [:a, :bars]

        @type t :: %__MODULE__{
                a: non_neg_integer(),
                bars: [Bar.t()]
              }
      end
    """

    use Plug.Builder
    alias DataSpecs.Types

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:load)

    @spec typeref(module(), Types.type_id()) :: [assigns: %{dataspec: %{type: Types.type_ref(), value: term()}}]

    @doc """
    Declare the type the body of a route should conform

    For example:
        post "/foo", typeref(Model.Foo, :t) do
          ...
        end
    """
    def typeref(module, type), do: [assigns: %{dataspec: %{type: {module, type}, value: nil}}]

    @spec value(Plug.Conn.t()) :: term()

    @doc """
    Get the value loaded.

    For example:
        mystruct = value(conn)
    """
    def value(conn), do: conn.assigns.dataspec.value

    @spec load(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
    defp load(conn, _opts) do
      with {:conn_dataspec, {:ok, type_ref}} <- {:conn_dataspec, conn_dataspec(conn)},
           {:load, {:ok, value}} <- {:load, DataSpecs.load(conn.body_params, type_ref)} do
        put_in(conn.assigns.dataspec.value, value)
      else
        {:conn_dataspec, :error} ->
          raise """
          Probably you missed a typeref on this route.

            post "/foo", #{__MODULE__}.typeref(Foo, :t) do
              ...
            end
          """

        {:load, {:error, reason}} ->
          conn
          |> resp(:bad_request, inspect(reason))
          |> halt()
      end
    end

    @spec conn_dataspec(map()) :: {:ok, Types.type_ref()} | :error
    defp conn_dataspec(%{assigns: %{dataspec: %{type: type_ref}}}), do: {:ok, type_ref}
    defp conn_dataspec(_), do: :error
  end
end

# coveralls-ignore-end
