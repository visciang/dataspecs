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
        import #{__MODULE__}, only: [typeref: 2, value: 1]

        plug :match
        plug #{__MODULE__}
        plug :dispatch

        post "/foo", typeref(Api.Model.Foo, :t) do
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
        post "/foo", typeref(Model.Foo) do
          ...
        end
    """
    def typeref(module, type \\ :t), do: [assigns: %{dataspec: %{type: {module, type}, value: nil}}]

    @spec value(Plug.Conn.t()) :: term()

    @doc """
    Get the loaded value.

    For example:
      post "/foo", typeref(Api.Model.Foo, :t) do
        %Api.Model.Foo{...} = value(conn)
        ...
      end
    """
    def value(conn), do: conn.assigns.dataspec.value

    @spec load(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
    defp load(conn, _opts) do
      with {:get_typeref, {:ok, type_ref}} <- {:get_typeref, get_typeref(conn)},
           {:load, {:ok, value}} <- {:load, DataSpecs.load(conn.body_params, type_ref)} do
        put_in(conn.assigns.dataspec.value, value)
      else
        {:get_typeref, :error} ->
          raise_missing_typeref()

        {:load, {:error, reason}} ->
          conn
          |> resp(:bad_request, inspect(reason))
          |> halt()
      end
    end

    @spec get_typeref(map()) :: {:ok, Types.type_ref()} | :error
    defp get_typeref(%{assigns: %{dataspec: %{type: type_ref}}}), do: {:ok, type_ref}
    defp get_typeref(_), do: :error

    @spec raise_missing_typeref :: no_return()
    def raise_missing_typeref do
      raise """
      Probably you missed a typeref on this route.

        post "/foo", #{__MODULE__}.typeref(Foo, :t) do
          ...
        end
      """
    end
  end
end

# coveralls-ignore-end
