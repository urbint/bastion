defmodule BastionTest do
  use ExUnit.Case
  doctest Bastion

  import Bastion

  defmodule BasicTestSchema do
    use Absinthe.Schema

    object :user do
      field :name, :string
      field :id, :integer
    end

    query do
      field :private_users, list_of(:user) do
        scopes :admin
        resolve &resolver_fn/3
      end
      field :public_users, list_of(:user) do
        resolve &resolver_fn/3
      end
    end

    defp resolver_fn(_parent, _args, _blueprint) do
      {:ok, [
        %{id: 7, name: "Luke Skywalker"},
        %{id: 999999, name: "Darth Vader"},
      ]}
    end
  end

  defp assert_query_returns_data(query) do
    result =
      query
      |> Absinthe.run(BasicTestSchema)
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

  describe "required_scopes/2 and authorize/3" do
    setup %{test_case: test_case} do
      basic_public = """
        query TestQuery {
          users:public_users {
            name, id
          }
        }
        """

      basic_private = """
        query TestQuery {
          users:private_users {
            name, id
          }
        }
        """

      context =
        case test_case do
          :basic ->
            %{public_query: basic_public, private_query: basic_private}
        end

      {:ok, context: context}
    end

    @tag test_case: :basic
    test "works as expected", %{context: context} do
      %{private_query: private_query, public_query: public_query} = context

      assert_query_returns_data(private_query)
      assert_query_returns_data(public_query)
    end

    @tag test_case: :basic
    test "returns required scopes for requested objects", %{context: context} do
      %{private_query: private_query, public_query: public_query} = context

      assert required_scopes(BasicTestSchema, private_query) == {:ok, [:admin]}
      assert required_scopes(BasicTestSchema, public_query) == :no_scopes_required
    end

    @tag test_case: :basic
    test "authorizes :admin for :admin scopes", %{context: context} do
      %{private_query: private_query, public_query: public_query} = context

      #private query
      assert :ok = authorize(BasicTestSchema, private_query, [:admin])
      assert {:error, _} = authorize(BasicTestSchema, private_query, [:user])
      assert {:error, _} = authorize(BasicTestSchema, private_query, [])

      # public query
      assert :ok = authorize(BasicTestSchema, public_query, [:admin])
      assert :ok = authorize(BasicTestSchema, public_query, [:user])
      assert :ok = authorize(BasicTestSchema, public_query, [])
    end

  end

end
