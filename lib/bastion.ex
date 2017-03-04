defmodule Bastion do
  @moduledoc """
  Bastion allows you to specify scopes in your Absinthe GraphQL Schemas,
  and then authorize requests only on requested fields.

  To use Bastion, you need to:

  1. Set scopes on your GraphQL fields via Bastion's `scopes` macro
  2. Set the authorized scopes on each Plug.Conn.t, via `Bastion.Plug.set_authorized_scopes/2`
  3. Call `plug Bastion.Plug` ahead of `plug Absinthe.Plug` in your router

  Bastion will reject requests to scoped fields that the user does not have an authorized scope for.

  Notably, the request is rejected only if a scoped field is included - requests for non projected fields will pass through.

  ## Example Usage

  In your Absinthe.Schema:

      defmodule MyAbsintheSchema do
        use Absinthe.Schema
        use Bastion

        query do
          field :users, list_of(:user) do
            scopes [:admin]
          end
        end

        object :user do
          field :name, :string
        end
      end

  In your router:

      defmodule MyRouter do
        use Plug

        plug :set_scopes

        defp set_scopes(conn, _opts) do
          # get authorized scopes from your own user or domain logic
          Bastion.Plug.set_authorized_scopes(conn, [:admin])
        end

        plug Bastion.Plug, schema: MyAbsintheSchema
        plug Absinthe.Plug, schema: MyAbsintheSchema
      end


  """

  @type scope :: atom
  @type query :: String.t

  @bastion_metadata_key :'$bastion:scopes'

  alias Absinthe.{Schema,Pipeline,Phase}


  @doc """
  required_scopes/2 takes an `Absinthe.Schema.t` and a Graphql query string,
  and returns the scopes required to run that query.

  """
  @spec required_scopes(Schema.t, query) :: {:ok, [scope]} | :no_scopes_required | {:error, :parse_failed}
  def required_scopes(schema, query) do
    with {:ok, metadata} <- metadata_for_requested_fields(schema, query) do
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

  @spec metadata_for_requested_fields(Schema.t, query) :: {:ok, Bastion.ExtractMetadata.extracted_metadata} | {:error, :parse_failed}
  defp metadata_for_requested_fields(schema, query) do
    pipeline =
      metadata_pipeline(schema)

    query
    |> Pipeline.run(pipeline)
    |> case do
      {:ok, result, _phases} ->
        {:ok, result}

      {:error, %{phase: Absinthe.Phase.Parse}, _phases} ->
        {:error, :parse_failed}
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
  @spec authorize(Schema.t, query, [scope]) :: {:ok, authorized? :: boolean} | {:error, :parse_failed}
  def authorize(schema, query, user_scopes) when is_list(user_scopes) do
    required_scopes(schema, query)
    |> case do
      {:ok, scopes} ->
        authorized? =
          scopes
          |> Enum.all?(&(&1 in user_scopes))

        {:ok, authorized?}

      :no_scopes_required ->
        {:ok, true}

      {:error, :parse_failed} = err ->
        err
    end
  end


  @doc """
  Allows a module to set scopes as a meta object on fields with no fuss.

  ## Usage

      query do
        field :my_secret_query, :secret, description: "" do
          scopes :admin_priviledges
        end
      end

  """
  defmacro scopes(req_scopes) do
    quote do
      meta unquote(@bastion_metadata_key), unquote(req_scopes)
    end
  end
end
