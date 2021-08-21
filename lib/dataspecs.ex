defmodule DataSpecs do
  @moduledoc File.read!("README.md")

  alias DataSpecs.{Types, Typespecs}

  @spec load(Types.value(), Types.type_ref(), Types.custom_type_loaders(), [Types.type_loader_fun()]) ::
          {:error, Types.reason()} | {:ok, any()}

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
  def load(value, {module, type_id}, custom_type_loaders \\ %{}, type_params_loaders \\ []) do
    loader = Typespecs.loader(module, type_id, length(type_params_loaders))
    loader.(value, custom_type_loaders, type_params_loaders)
  end
end
