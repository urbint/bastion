# Bastion

## Installation

Bastion can be installed by adding `bastion` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bastion, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bastion](https://hexdocs.pm/bastion).


## Module doc from [Bastion main file](https://github.com/urbint/bastion/blob/master/lib/bastion.ex)

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
        scopes :admin
      end

      field :users, list_of(:user) do
        scopes :admin
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
