defmodule DoormanTest do
  use ExUnit.Case
  doctest Doorman

  alias __MODULE__.TestSchema

  describe "sanity" do
    test "TestSchema module works as expected" do
      """
      query TestQuery {
        all_planets {
          name, id
        }
      }
      """ |> Absinthe.run(TestSchema)
      |> case do
           {:ok, result} ->
             assert result ==
               %{data:
                 %{"all_planets" => [
                   %{"id" => 7, "name" => "Mars"},
                   %{"id" => 999999, "name" => "Dagobah"}
                 ]}
                }
      end
    end
  end

  describe "required_scopes/2" do
    test "returns scopes specified by the schema metadata"
  end


  defmodule TestSchema do
    @moduledoc false

    use Absinthe.Schema

    object :planet do
      field :name, :string
      field :id, :integer
    end

    query do
      field :all_planets, list_of(:planet),
        resolve: &resolver_fn/3
    end

    defp resolver_fn(_, _, _) do
      {:ok, [
        %{id: 7, name: "Mars"},
        %{id: 999999, name: "Dagobah"},
      ]}
    end

  end


end
