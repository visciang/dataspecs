defmodule DataSpecs.Schema.Quoted do
  @moduledoc """
  Utilities to convert a schema type to a quoted form.
  """

  alias DataSpecs.Schema.Type

  @doc """
  Convert a schema to a quoted representation.
  """
  @spec from_schema(Type.t()) :: Macro.t()
  def from_schema(%Type{} = t) do
    from_schema_(t)
  end

  @spec from_schema_(Type.t() | Type.type()) :: Macro.t()
  defp from_schema_(%Type{} = t) do
    q_type_vars = Enum.map(t.vars, fn %Type.Var{id: id} -> {id, [], Elixir} end)
    type_module = t.module |> Module.split() |> Enum.map(&String.to_atom/1)

    {:@, [],
     [
       {t.visibility, [],
        [
          {:"::", [],
           [
             {{:., [], [{:__aliases__, [alias: false], type_module}, t.id]}, [], q_type_vars},
             from_schema_(t.type)
           ]}
        ]}
     ]}
  end

  defp from_schema_(%Type.Literal.Atom{} = t) do
    t.value
  end

  defp from_schema_(%Type.Literal.Integer{} = t) do
    t.value
  end

  defp from_schema_(%Type.Builtin{} = t) do
    {t.id, [], []}
  end

  defp from_schema_(%Type.Bitstring{} = t) do
    case {t.unit, t.size} do
      {0, 0} ->
        {:<<>>, [], []}

      {0, size} ->
        {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, size]}]}

      {unit, 0} ->
        {:<<>>, [],
         [
           {:"::", [],
            [
              {:_, [], Elixir},
              {:*, [], [{:_, [], Elixir}, unit]}
            ]}
         ]}

      {size, unit} ->
        {:<<>>, [],
         [
           {:"::", [], [{:_, [], Elixir}, unit]},
           {:"::", [],
            [
              {:_, [], Elixir},
              {:*, [], [{:_, [], Elixir}, size]}
            ]}
         ]}
    end
  end

  defp from_schema_(%Type.Range{} = t) do
    {:.., [], [t.lower, t.upper]}
  end

  defp from_schema_(%Type.Var{} = t) do
    {t.id, [], Elixir}
  end

  defp from_schema_(%Type.Union{} = t) do
    case t.of do
      [a, b] -> {:|, [], [from_schema_(a), from_schema_(b)]}
      [a | rest] -> {:|, [], [from_schema_(a), from_schema_(%Type.Union{of: rest})]}
    end
  end

  defp from_schema_(%Type.List{} = t) do
    case t.cardinality do
      0 -> []
      :+ -> [from_schema_(t.of), {:..., [], Elixir}]
      _ -> [from_schema_(t.of)]
    end
  end

  defp from_schema_(%Type.Tuple{} = t) do
    case t.cardinality do
      :* -> {:tuple, [], []}
      2 -> t.of |> Enum.map(&from_schema_/1) |> List.to_tuple()
      _ -> {:{}, [], Enum.map(t.of, &from_schema_/1)}
    end
  end

  defp from_schema_(%Type.Map{} = t) do
    kv =
      Enum.map(t.of, fn {%Type.Map.Key{} = key, value} ->
        if key.required? do
          {from_schema_(key.type), from_schema_(value)}
        else
          {{:optional, [], [from_schema_(key.type)]}, from_schema_(value)}
        end
      end)

    {:%{}, [], kv}
  end

  defp from_schema_(%Type.Ref{} = t) do
    q_type_params = Enum.map(t.params, &from_schema_/1)
    type_module = t.module |> Module.split() |> Enum.map(&String.to_atom/1)

    {{:., [], [{:__aliases__, [alias: false], type_module}, t.id]}, [], q_type_params}
  end

  defp from_schema_(%Type.Unsupported{}) do
    :__unsupported__
  end
end
