defmodule Mix.Tasks.Dataspecs.Schema.Dump do
  @shortdoc "Dump a type schema"

  @moduledoc """
  #{@shortdoc}.

      mix dataspecs.schema.dump MyModule
  """

  @requirements ["app.start"]

  use Mix.Task

  @impl Mix.Task
  def run([module]) do
    module = String.to_atom("Elixir.#{module}")

    Code.Typespec.fetch_types(module)

    # schema = DataSpecs.Schema.load(module)

    # Mix.shell().info(inspect(schema))
  end
end
