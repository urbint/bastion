defmodule Bastion do
  @moduledoc """
  Bastion uses metadata from your GraphQL Schema to authorize requests.

  """

  @type scope :: atom
  @type query :: String.t


  @doc """
  required_scopes/2 takes an `Absinthe.Schema.t` and a Graphql query string,
  and returns the scopes required to run that query.

  """
  @spec required_scopes(Absinthe.Schema.t, query) :: [scope]
  def required_scopes(schema, query) do
    parse_to_absinthe_blueprint(schema, query)
    |> IO.inspect

    []
  end

  defp parse_to_absinthe_blueprint(schema, query) do
    pipeline = get_pipeline_for_query(schema)
    case Absinthe.Pipeline.run(query, pipeline) do
      {:ok, result, _phases} ->
        {:ok, result}
      {:error, msg, _phases} ->
        {:error, msg}
    end
  end

  defp get_pipeline_for_query(schema) do
    opts =
      [
        adapter: Absinthe.Adapter.LanguageConventions,
        operation_name: nil,
        variables: %{},
        context: %{},
        root_value: %{},
        validation_result_phase: Absinthe.Phase.Document.Validation.Result,
        result_phase: Absinthe.Phase.Document.Result,
        jump_phases: true,
        schema: schema,
      ]

    [
      {Absinthe.Phase.Parse, opts},
      Absinthe.Phase.Blueprint,
      {Absinthe.Phase.Schema, opts},
    ]
  end


  @doc """
  authentication/3 takes an `Absinthe.Schema.t`, a Graphql query string, and a list of scopes.

  If every scope required to execute the query are represented in the passed list, :ok is returned.
  Otherwise, {:error, reason} is returned.

  """
  @spec authorize(Absinthe.Schema.t, query, [scope]) :: :ok | {:error, reason :: String.t}
  def authorize(schema, query, user_scopes) do
    necessary_scopes =
      required_scopes(schema, query)

    authorized? =
      Enum.all?(user_scopes in necessary_scopes)

    if authorized? do
      :ok
    else
      {:error, "Not authorized to execute query."}
    end
  end
end
