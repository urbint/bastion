defmodule BastionTest do
  use ExUnit.Case
  doctest Bastion

  import Bastion

  defmodule BasicTestSchema do
    use Absinthe.Schema

    object :user do
      field :name, :string
      field :id, :integer
      field :secret, :string do
        scopes :user
      end
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
        %{id: 7, name: "Luke Skywalker", secret: "kissed his sister"},
        %{id: 999999, name: "Darth Vader", secret: "afraid of snakes"},
      ]}
    end
  end

  defp assert_query_returns_data(query, user_data) do
    result =
      query
      |> Absinthe.run(BasicTestSchema)
      |> case do
        {:ok, result} ->
          result
      end

    %{data: %{"users" => users}} = result

    assert users == user_data
  end

  describe "required_scopes/2 and authorize/3" do
    setup %{query: query} do
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

      user_asking_for_secret = """
        query TestQuery {
          users:public_users {
            name, id, secret
          }
        }
        """

      user_data =
        [
          %{"id" => 7, "name" => "Luke Skywalker"},
          %{"id" => 999999, "name" => "Darth Vader"}
        ]

      user_data_with_secrets =
        [
          %{"id" => 7, "name" => "Luke Skywalker", "secret" => "kissed his sister"},
          %{"id" => 999999, "name" => "Darth Vader", "secret" => "afraid of snakes"},
        ]

      {query, data} =
        case query do
          :basic_public ->
            {basic_public, user_data}
          :basic_private ->
            {basic_private, user_data}
          :user_asking_for_secret ->
            {user_asking_for_secret, user_data_with_secrets}
        end

      {:ok, query: query, data: data}
    end

    @tag query: :basic_public
    test "basic_public query works as expected", %{query: query, data: data} do
      assert_query_returns_data(query, data)
    end

    @tag query: :basic_private
    test "basic_private query works as expected", %{query: query, data: data} do
      assert_query_returns_data(query, data)
    end

    @tag query: :user_asking_for_secret
    test "user_asking_for_secret query works as expected", %{query: query, data: data} do
      assert_query_returns_data(query, data)
    end

    @tag query: :basic_public
    test "basic_public query returns required scopes for requested objects", %{query: query} do
      assert required_scopes(BasicTestSchema, query) == :no_scopes_required
    end

    @tag query: :basic_private
    test "basic_private query returns required scopes for requested objects", %{query: query} do
      assert required_scopes(BasicTestSchema, query) == {:ok, [:admin]}
    end

    @tag query: :user_asking_for_secret
    test "user_asking_for_secret query returns required scopes for requested objects", %{query: query} do
      assert required_scopes(BasicTestSchema, query) == {:ok, [:user]}
    end

    @tag query: :basic_public
    test "authorizes a basic public query", %{query: query} do
      assert :ok = authorize(BasicTestSchema, query, [:admin])
      assert :ok = authorize(BasicTestSchema, query, [:user])
      assert :ok = authorize(BasicTestSchema, query, [])
    end

    @tag query: :basic_private
    test "authorizes only properly scoped private queries", %{query: query} do
      assert :ok           = authorize(BasicTestSchema, query, [:admin])
      assert :unauthorized = authorize(BasicTestSchema, query, [:user])
      assert :unauthorized = authorize(BasicTestSchema, query, [])
    end

    @tag query: :user_asking_for_secret
    test "authorizes only properly scoped sub-field queries", %{query: query} do
      assert :ok           = authorize(BasicTestSchema, query, [:user])
      assert :unauthorized = authorize(BasicTestSchema, query, [:admin])
      assert :unauthorized = authorize(BasicTestSchema, query, [])
    end
  end

end
