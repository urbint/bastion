defmodule Bastion.Plug do
  @moduledoc """
  A plug adapter that enforces authorization for GraphQL requests.

  """

  @behaviour Plug
  # import Plug.Conn

  @spec init(opts :: Keyword.t) :: map
  def init(opts \\ []) do
    opts
  end


  @doc """
  Call asserts that the user making the request
  has access to the requested fields.

  """
  def call(conn, _opts) do
    conn
    |> IO.inspect
  end
end
