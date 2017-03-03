defmodule Bastion.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test


  @opts Bastion.Plug.init([])

  test "returns the connection" do
    conn =
      conn(:get, "/")

    passed_conn = Bastion.Plug.call(conn, @opts)

    assert conn == passed_conn
  end
end
