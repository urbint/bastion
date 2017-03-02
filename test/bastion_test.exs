defmodule BastionTest do
  use ExUnit.Case
  doctest Bastion

  alias __MODULE__.TestSchema

  import Bastion

  describe "required_scopes/2" do
    setup do
      private_query = """
        query TestQuery {
          users:private_users {
            name, id
          }
        }
        """

      public_query = """
        query TestQuery {
          users:public_users {
            name, id
          }
        }
        """

      {:ok, private_query: private_query, public_query: public_query}
    end

    test "works as expected", %{private_query: private_query, public_query: public_query} do
      assert_query_returns_data(private_query)
      assert_query_returns_data(public_query)
    end

    test "returns scopes specified by the schema and query request metadata",
      %{private_query: private_query, public_query: public_query}
    do
      assert required_scopes(TestSchema, private_query) == {:ok, [:admin]}
      assert required_scopes(TestSchema, public_query) == :no_scopes_required
    end

    test "authorizes :admin for :admin scopes",
      %{private_query: private_query, public_query: public_query}
    do
      #private query
      assert :ok = authorize(TestSchema, private_query, [:admin])
      assert {:error, _} = authorize(TestSchema, private_query, [:user])
      assert {:error, _} = authorize(TestSchema, private_query, [])

      # public query
      assert :ok = authorize(TestSchema, public_query, [:admin])
      assert :ok = authorize(TestSchema, public_query, [:user])
      assert :ok = authorize(TestSchema, public_query, [])
    end

    defp assert_query_returns_data(query) do
      result =
        query
        |> Absinthe.run(TestSchema)
        |> case do
          {:ok, result} ->
            result
        end

      assert result ==
        %{data:
          %{"users" => [
            %{"id" => 7, "name" => "Luke Skywalker"},
            %{"id" => 999999, "name" => "Darth Vader"}
          ]}
        }
    end

  end


  defmodule TestSchema do
    @moduledoc false

    use Absinthe.Schema

    object :private_user do
      meta :scopes, :admin

      field :name, :string
      field :id, :integer
    end

    object :public_user do
      field :name, :string
      field :id, :integer
    end

    query do
      field :private_users, list_of(:private_user),
        resolve: &resolver_fn/3

      field :public_users, list_of(:public_user),
        resolve: &resolver_fn/3
    end

    defp resolver_fn(_parent, _args, _blueprint) do
      {:ok, [
        %{id: 7, name: "Luke Skywalker"},
        %{id: 999999, name: "Darth Vader"},
      ]}
    end
  end
end
