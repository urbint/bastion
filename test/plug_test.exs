defmodule Bastion.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule PlugTestSchema do
    use Absinthe.Schema
    import Bastion

    query do
      field :secrets, :string do
        scopes [:admin, :c_level]
        resolve {:ok, "secret info"}
      end

      field :public_info, :string do
        resolve {:ok, "public info"}
      end
    end

    object :obj do
      field :str, :string
    end
  end

  @opts Bastion.Plug.init([schema: PlugTestSchema])

  @secrets_query "{secrets}"
  @public_query "{public_info}"

  describe "for unscoped users" do
    test "rejects unauthorized requests to secrets" do
      for conn <- supported_calls_with_query(@secrets_query) do
        conn =
          Bastion.Plug.call(conn, @opts)

        assert conn.status == 403
        assert conn.halted == true
        assert conn.state == :sent

        assert Poison.decode!(conn.resp_body) == %{
          "errors" => [%{"message" => "Unauthorized"}]
        }
      end
    end

    test "accepts authorized requests to secrets" do
      for conn <- supported_calls_with_query(@secrets_query, [:admin, :c_level]) do
        passed_conn =
          Bastion.Plug.call(conn, @opts)

        assert conn.status == passed_conn.status
        assert conn == passed_conn
      end
    end

    test "accepts requests to public info" do
      for conn <- supported_calls_with_query(@public_query) do
        passed_conn =
          Bastion.Plug.call(conn, @opts)

        assert conn == passed_conn
      end
    end

    test "rejects invalid queries" do
      for conn <- supported_calls_with_query("invalid}") do
        conn =
          Bastion.Plug.call(conn, @opts)

        assert conn.halted == true
        assert conn.state == :sent
        assert conn.status == 400

        assert Poison.decode!(conn.resp_body) == %{
          "errors" => [%{"message" => "Invalid query"}]
        }
      end
    end
  end

  @spec supported_calls_with_query(String.t, [Bastion.scope]) :: [Plug.Conn.t]
  defp supported_calls_with_query(query, scopes \\ []) do
    call_types = [
        {"application/graphql", query},
        {"application/x-www-form-urlencoded", query: query},
        {"application/json", Poison.encode!(%{query: query})},
      ]

    for {content_type, body} <- call_types do
      conn(:post, "/", body)
      |> put_req_header("content-type", content_type)
      |> plug_parser()
      |> Bastion.Plug.set_authorized_scopes(scopes)
    end
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end
end
