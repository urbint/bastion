defmodule Bastion do
  @moduledoc """
  Bastion uses metadata from your GraphQL Schema to authorize requests.

  """

  @type scope :: atom
  @type query :: String.t

  alias Absinthe.{Schema,Blueprint,Pipeline,Adapter,Phase,Type}

  @doc """
  required_scopes/2 takes an `Absinthe.Schema.t` and a Graphql query string,
  and returns the scopes required to run that query.

  """
  @spec required_scopes(Schema.t, query) :: [scope]
  def required_scopes(schema, query) do
    {:ok, blueprint} =
      parse_to_absinthe_blueprint(schema, query)

    blueprint
    |> parse_requested_fields()
    |> Stream.map(&Schema.lookup_type(schema, &1))
    |> Stream.filter(&(&1))
    |> Stream.map(&Type.meta(&1, :bastion))
    |> Stream.filter(&(&1))
    |> Enum.uniq()
  end

  @spec parse_to_absinthe_blueprint(Schema.t, query) :: Blueprint.t
  defp parse_to_absinthe_blueprint(schema, query) do
    pipeline = get_pipeline_for_query(schema)
    case Pipeline.run(query, pipeline) do
      {:ok, result, _phases} ->
        {:ok, result}
      {:error, msg, _phases} ->
        {:error, msg}
    end
  end

  defp get_pipeline_for_query(schema) do
    opts =
      [
        adapter: Adapter.LanguageConventions,
        operation_name: nil,
        variables: %{},
        context: %{},
        root_value: %{},
        validation_result_phase: Phase.Document.Validation.Result,
        result_phase: Phase.Document.Result,
        jump_phases: true,
        schema: schema,
      ]

    [
      {Phase.Parse, opts},
      Phase.Blueprint,
      {Phase.Schema, opts},
    ]
  end

  @spec parse_requested_fields(Blueprint.t) :: [Blueprint.Document.Field.t]
  defp parse_requested_fields(blueprint) do
    blueprint.operations
    |> collect_object_field_ids()
  end

  @spec collect_object_field_ids([Blueprint.Document.Operation.t]) :: [atom]
  defp collect_object_field_ids(operations) do
    do_collect_object_field_ids(operations, [])
  end

  defp do_collect_object_field_ids([], acc), do: acc
  defp do_collect_object_field_ids([next | rest], acc) do
    ids =
      next.selections
      |> Enum.flat_map(&fields_for_selections/1)

    do_collect_object_field_ids(rest, ids ++ acc)
  end

  defp fields_for_selections(%Blueprint.Document.Field{schema_node: %{type: %Type.List{of_type: type}}, selections: selections}) do
    selections
    |> Enum.flat_map(&fields_for_selections/1)
    |> Enum.concat([type])
  end
  defp fields_for_selections(%Blueprint.Document.Field{schema_node: %{__reference__: %{identifier: id}}}) when not(is_nil(id)) do
    [id]
  end

  @spec parse_requested_scopes([Blueprint.Document.Field.t]) :: [scope]
  defp parse_requested_scopes([field | _]) do
    field.name


    field.schema_node.name
    |> String.to_existing_atom
    |> Type.meta(:bastion)
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
