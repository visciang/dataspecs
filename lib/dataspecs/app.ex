defmodule DataSpecs.App do
  @moduledoc false

  use Application

  @impl Application
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    Supervisor.start_link([DataSpecs.Cache], strategy: :one_for_one)
  end
end
