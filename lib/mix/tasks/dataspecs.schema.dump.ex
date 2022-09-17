defmodule Mix.Tasks.Dataspecs.Schema.Dump do
  @shortdoc "Dump a type schema"

  @moduledoc """
  #{@shortdoc}.

      mix dataspecs.schema.dump MyModule
  """

  @requirements ["app.config"]

  use Mix.Task

  @impl Mix.Task
  def run([module]) do
    "Elixir.#{module}"
    |> String.to_atom()
    |> DataSpecs.Schema.load()
    |> inspect_schema()
    |> Mix.shell().info()
  end

  defp inspect_schema(schema) do
    syntax_colors =
      if Version.compare(System.version(), "1.14.0") in [:eq, :gt] do
        [syntax_colors: IO.ANSI.syntax_colors()]
      else
        []
      end

    inspect(schema, [pretty: true, limit: :infinity] ++ syntax_colors)
  end
end
