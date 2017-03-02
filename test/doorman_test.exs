defmodule DoormanTest do
  use ExUnit.Case
  doctest Doorman

  alias __MODULE__.TestSchema

  import Doorman

  describe "sanity" do
    test "TestSchema module works as expected" do
      """
      query TestQuery {
        users {
          name, id
        }
      }
      """
      |> Absinthe.run(TestSchema)
      |> case do
           {:ok, result} ->
             assert result ==
               %{data:
                 %{"users" => [
                   %{"id" => 7, "name" => "Luke Skywalker"},
                   %{"id" => 999999, "name" => "Darth Vader"}
                 ]}
                }
      end
    end
  end

  describe "required_scopes/2" do
    test "returns scopes specified by the schema and query request metadata" do
      query = """
        query TestQuery {
          users {
            name, id
          }
        }
        """

      assert required_scopes(TestSchema, query) == [:admin]
    end
  end


  defmodule TestSchema do
    @moduledoc false

    use Absinthe.Schema

    object :user do
      meta :doorman, :admin
      field :name, :string
      field :id, :integer
    end


    query do
      field :users, list_of(:user),
        resolve: &resolver_fn/3
    end

    defp resolver_fn(_, _, _) do
      {:ok, [
        %{id: 7, name: "Luke Skywalker"},
        %{id: 999999, name: "Darth Vader"},
      ]}
    end

  end


end
