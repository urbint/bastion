defmodule Bastion do
  @moduledoc """
  Bastion uses metadata from your GraphQL Schema to authorize requests.

  """

  @type scope :: atom
  @type query :: String.t

  alias Absinthe.{Schema,Pipeline,Phase}

  @doc """
  required_scopes/2 takes an `Absinthe.Schema.t` and a Graphql query string,
  and returns the scopes required to run that query.

  """
  @spec required_scopes(Schema.t, query) :: [scope]
  def required_scopes(schema, query) do
    {:ok, metadata} =
      metadata_for_requested_fields(schema, query)

    metadata
    |> Stream.flat_map(&extract_scopes/1)
    |> Enum.uniq()
  end

  @spec extract_scopes(Bastion.ExtractMetadata.extracted_metadata) :: [scope]
  defp extract_scopes({ _id, meta}) do
    meta
    |> Map.get(:scopes)
    |> List.wrap()
  end

  @spec metadata_for_requested_fields(Schema.t, query) :: {:ok, Bastion.ExtractMetadata.extracted_metadata}
  defp metadata_for_requested_fields(schema, query) do
    pipeline = metadata_pipeline(schema)

    Pipeline.run(query, pipeline)
    |> case do
      {:ok, result, _phases} ->
        {:ok, result}
    end
  end

  @spec metadata_pipeline(Schema.t) :: Pipeline.t
  defp metadata_pipeline(schema) do
    opts =
      [schema: schema]

    [
      {Phase.Parse, opts},
      Phase.Blueprint,
      {Phase.Schema, opts},
      {Bastion.ExtractMetadata, opts},
    ]
  end


  @doc """
  authentication/3 takes an `Schema.t`, a Graphql query string, and a list of scopes.

  If every scope required to execute the query are represented in the passed list, :ok is returned.
  Otherwise, {:error, reason} is returned.

  """
  @spec authorize(Schema.t, query, [scope]) :: :ok | {:error, reason :: String.t}
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
