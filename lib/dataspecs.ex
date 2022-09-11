defmodule DataSpecs do
  @moduledoc """
  DataSpecs.
  """

  alias DataSpecs.{Loader, Types}

  @doc """
  Defines a load helper function in a struct module.

  ```elixir
  defmodule Person do
    use DataSpecs

    @enforce_keys [:name, :surname]
    defstruct @enforce_keys ++ [:birth_date]

    @type t :: %__MODULE__{
                name: String.t(),
                surname: String.t(),
                birth_date: nil | Date.t(),
              }
  end
  ```

  ```elixir
  Person.load(%{"name" => "John", surname => "Smith", "birth_date": "1980-12-31"})

  %Person{
    name: "John",
    surname: "Smith",
    birth_date: ~D[1980-12-31]
  }
  ```

  equivalent to

  ```elixir
  DataSpecs.load(%{"name" => "John", surname => "Smith"}, {Person, :t})
  ```
  """
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @spec load(DataSpecs.Types.value(), DataSpecs.Types.custom_type_loaders()) ::
              DataSpecs.Types.load_result(__MODULE__.t())

      @doc """
      Loads a value that should conform to #{__MODULE__}.t() typespec.
      """
      def load(data, custom_type_loaders \\ nil) do
        if custom_type_loaders do
          DataSpecs.load(data, {__MODULE__, :t}, custom_type_loaders)
        else
          DataSpecs.load(data, {__MODULE__, :t})
        end
      end
    end
  end

  @doc """
  Loads a value that should conform to a typespec.

  > #### Info {: .info}
  >
  > `custom_type_loaders` defaults to `DataSpecs.Loader.Extra.type_loaders/0`.
  > This will by default map types such as `t:Date.t/0`, `t:DateTime.t/0`, `t:MapSet.t/0`, ...
  > as describer in the module documentation.
  """
  @spec load(
          data :: Types.value(),
          type_ref :: Types.type_ref(),
          custom_type_loaders :: Types.custom_type_loaders(),
          type_params_loaders :: [Types.type_loader_fun()]
        ) ::
          Types.load_result(term())
  def load(value, {module, type_id}, custom_type_loaders \\ Loader.Extra.type_loaders(), type_params_loaders \\ []) do
    loader = Loader.get(module, type_id, length(type_params_loaders))
    loader.(value, custom_type_loaders, type_params_loaders)
  end
end
