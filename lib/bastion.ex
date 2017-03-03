defmodule Bastion do
  @moduledoc """
  Bastion uses metadata from your GraphQL Schema to authorize requests.

  """

  @type scope :: atom
  @type query :: String.t

  @bastion_metadata_key :'$bastion:scopes'

  alias Absinthe.{Schema,Pipeline,Phase}


  @doc """
  required_scopes/2 takes an `Absinthe.Schema.t` and a Graphql query string,
  and returns the scopes required to run that query.

  """
  @spec required_scopes(Schema.t, query) :: {:ok, [scope]} | :no_scopes_required
  def required_scopes(schema, query) do
    {:ok, metadata} =
      metadata_for_requested_fields(schema, query)

    scopes =
      metadata
      |> Stream.flat_map(&extract_scopes/1)
      |> Enum.uniq()

    case scopes do
      [] ->
        :no_scopes_required

      scopes ->
        {:ok, scopes}
    end
  end

  @spec extract_scopes(Bastion.ExtractMetadata.extracted_metadata) :: [scope]
  defp extract_scopes(meta) do
    meta
    |> Keyword.fetch(@bastion_metadata_key)
    |> case do
      :error ->
        []

      {:ok, scopes} ->
        scopes
    end
    |> List.wrap()
  end

  @spec metadata_for_requested_fields(Schema.t, query) :: {:ok, Bastion.ExtractMetadata.extracted_metadata}
  defp metadata_for_requested_fields(schema, query) do
    pipeline =
      metadata_pipeline(schema)

    query
    |> Pipeline.run(pipeline)
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
  @spec authorize(Schema.t, query, [scope]) :: :ok | :unauthorized
  def authorize(schema, query, user_scopes) when is_list(user_scopes) do
    authorized? =
      required_scopes(schema, query)
      |> case do
        {:ok, scopes} ->
          scopes
          |> Enum.all?(&(&1 in user_scopes))

        :no_scopes_required ->
          true
      end

    case authorized? do
      true ->
        :ok

      false ->
        :unauthorized
    end
  end


  @doc """
  Allows a module to set scopes as a meta object on fields with no fuss.

  """
  defmacro scopes(req_scopes) do
    quote do
      meta unquote(@bastion_metadata_key), unquote(req_scopes)
    end
  end
end
