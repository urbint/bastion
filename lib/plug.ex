defmodule Bastion.Plug do
  @moduledoc """
  A plug adapter that enforces authorization for GraphQL requests.

  """

  @behaviour Plug
  import Plug.Conn

  @type opts :: [
    {:schema, Absinthe.Schema.t}
  ]

  @bastion_scopes_conn_key :'$bastion:authorized_scopes'


  @doc """
  Ensures the passed or globally set schema option is a valid `Absinthe.Schema.t`.

  """
  @spec init(opts) :: opts
  def init(opts \\ []) do
    schema =
      get_schema(opts)

    Keyword.update(opts, :schema, schema, fn _ -> schema end)
  end

  @spec get_schema(opts) :: Absinthe.Schema.t
  defp get_schema(opts) do
    default = Application.get_env(:absinthe, :schema)
    schema = Keyword.get(opts, :schema, default)
    try do
      Absinthe.Schema.types(schema)
    rescue
      UndefinedFunctionError ->
        raise ArgumentError, "The supplied schema: #{inspect schema} is not a valid Absinthe Schema"
    end
    schema
  end


  @doc """
  Call asserts that the user making the request
  has access to the requested fields.

  """
  @spec call(Plug.Conn.t, opts) :: Plug.Conn.t
  def call(conn, opts) do
    schema =
      Keyword.fetch!(opts, :schema)

    with {:ok, query}  <- get_query(conn),
         {:ok, scopes} when is_list(scopes) <- get_authorized_scopes(conn),
         {:ok, true}   <- Bastion.authorize(schema, query, scopes) do
      conn
    else
      {:ok, false} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Poison.encode!(%{errors: [%{message: "Unauthorized"}]}))
        |> halt()

      {:error, :parse_failed} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Poison.encode!(%{errors: [%{message: "Invalid query"}]}))
        |> halt()
    end
  end

  @spec get_query(Plug.Conn.t) :: {:ok, String.t} | no_return
  defp get_query(%{body_params: %{"query" => query}}), do: {:ok, query}
  defp get_query(%{params: %{"query" => query}}), do: {:ok, query}

  @spec get_authorized_scopes(Plug.Conn.t) :: {:ok, [Bastion.scope]} | no_return
  defp get_authorized_scopes(conn) do
    if Map.has_key?(conn.assigns, @bastion_scopes_conn_key) do
      scopes =
        Map.get(conn.assigns, @bastion_scopes_conn_key)

      {:ok, scopes}
    else
      raise "No Bastion scopes set on connection"
    end
  end


  @doc """
  Sets authorized scopes on a passed Conn string.

  """
  @spec set_authorized_scopes(Plug.Conn.t, [Bastion.scope]) :: Plug.Conn.t
  def set_authorized_scopes(conn, scopes) do
    conn
    |> assign(@bastion_scopes_conn_key, scopes)
  end

end
