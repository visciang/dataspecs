defmodule DataSpecs do
  @moduledoc File.read!("README.md")

  alias DataSpecs.Typespecs

  @type value() :: any()
  @type reason :: [String.t() | reason()]
  @type type_id :: atom()
  @type type_ref :: {module(), type_id()}
  @type custom_type_ref :: {module(), type_id(), arity()}
  @type type_params_loader :: (value(), custom_type_loaders(), [type_params_loader] -> value())
  @type custom_type_loaders :: %{custom_type_ref() => type_params_loader()}

  @doc """
  Loads a value that should conform to a typespec

  Given a Person.t/1 typespec:

    DataSpecs.load(%{
      "name" => "Joe",
      "surname" => "Smith",
      "gender" => "male",
      "address" => [%{
        "streetname" => "High Street",
        "streenumber" => "3a",
        "postcode" => "SO31 4NG",
        "town" => "Hedge End, Southampton"
      }]
    }, {Person, :t})

    => %Person{
         address: [
           %Address{
             postcode: "SO31 4NG",
             streenumber: "3a",
             streetname: "High Street",
             town: "Hedge End, Southampton"
           }
         ],
         gender: :male,
         name: "Joe",
         surname: "Smith"
       }
  """
  @spec load(value(), type_ref(), custom_type_loaders(), [type_params_loader()]) :: {:error, reason()} | {:ok, value()}
  def load(value, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    loader = Typespecs.loader(module, type_id, length(type_params_loaders))
    loader.(value, custom_type_loaders, type_params_loaders)
  end
end
