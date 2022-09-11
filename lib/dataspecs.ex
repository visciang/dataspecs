defmodule DataSpecs do
  @moduledoc """
  DataSpecs.
  """

  alias DataSpecs.{Cast, Types}

  @doc """
  Defines a cast helper function in a struct module.

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
  Person.cast(%{"name" => "John", surname => "Smith", "birth_date": "1980-12-31"})

  %Person{
    name: "John",
    surname: "Smith",
    birth_date: ~D[1980-12-31]
  }
  ```

  equivalent to

  ```elixir
  DataSpecs.cast(%{"name" => "John", surname => "Smith"}, {Person, :t})
  ```
  """
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @doc """
      Cast a value that should conform to #{inspect(__MODULE__)}.t() typespec.
      """
      @spec cast(DataSpecs.Types.value(), nil | DataSpecs.Types.custom_type_casts()) ::
              DataSpecs.Types.cast_result(__MODULE__.t())
      def cast(data, custom_type_casts \\ nil) do
        if custom_type_casts do
          DataSpecs.cast(data, {__MODULE__, :t}, custom_type_casts)
        else
          DataSpecs.cast(data, {__MODULE__, :t})
        end
      end
    end
  end

  @doc """
  Cast a value that should conform to a typespec.

  > #### Info {: .info}
  >
  > `custom_type_casts` defaults to `DataSpecs.Cast.Extra.type_casts/0`.
  > This will by default map types such as `t:Date.t/0`, `t:DateTime.t/0`, `t:MapSet.t/0`, ...
  > as describer in the module documentation.
  """
  @spec cast(
          data :: Types.value(),
          type_ref :: Types.type_ref(),
          custom_type_casts :: Types.custom_type_casts(),
          type_params_casts :: [Types.type_cast_fun()]
        ) ::
          Types.cast_result(term())
  def cast(value, {module, type_id}, custom_type_casts \\ Cast.Extra.type_casts(), type_params_casts \\ []) do
    cast = Cast.get(module, type_id, length(type_params_casts))
    cast.(value, custom_type_casts, type_params_casts)
  end
end
