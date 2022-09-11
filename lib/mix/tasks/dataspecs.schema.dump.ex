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
    "Elixir.#{module}"
    |> String.to_atom()
    |> DataSpecs.Schema.load()
    |> inspect(pretty: true, limit: :infinity)
    |> Mix.shell().info()
  end
end
