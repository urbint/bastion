defmodule Bastion.ExtractMetadata do
  @moduledoc """
  An `Absinthe.Phase.t` that extracts the metadata for the fields in the passed `Absinthe.Blueprint.t`

  """


  alias Absinthe.{Schema,Blueprint,Type}

  use Absinthe.Phase

  @type id :: atom
  @type metadata :: map

  @type extracted_metadata :: {id, metadata}

  @spec run(Blueprint.t, Keyword.t) :: {:ok, [extracted_metadata]}
  def run(blueprint, opts \\ []) do
    schema =
      Keyword.fetch!(opts, :schema)

    extracted =
      blueprint
      |> parse_requested_fields()
      |> Stream.map(&extract_meta_for_identifier(schema, &1))
      |> Enum.reject(&elem(&1, 1) == nil)

    {:ok, extracted}
  end

  @spec extract_meta_for_identifier(Schema.t, id) :: extracted_metadata
  defp extract_meta_for_identifier(schema, id) do
    meta =
      schema
      |> Schema.lookup_type(id)
      |> case do
        nil ->
          nil

        type ->
          Type.meta(type)
      end

    {id, meta}
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
    |> Stream.flat_map(&fields_for_selections/1)
    |> Enum.concat([type])
  end
  defp fields_for_selections(%Blueprint.Document.Field{schema_node: %{__reference__: %{identifier: id}}}) when not(is_nil(id)) do
    [id]
  end

end
