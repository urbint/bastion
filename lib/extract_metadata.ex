defmodule Bastion.ExtractMetadata do
  @moduledoc """
  An `Absinthe.Phase.t` that extracts the metadata for the fields in the passed `Absinthe.Blueprint.t`

  """

  alias Absinthe.Blueprint

  use Absinthe.Phase

  @type id :: atom
  @type metadata :: map

  @type extracted_metadata :: {id, metadata}

  @spec run(Blueprint.t, Keyword.t) :: {:ok, [extracted_metadata]}
  def run(blueprint, _opts \\ []) do
    extracted =
      blueprint
      |> parse_selected_field_metadata()

    {:ok, extracted}
  end

  @spec parse_selected_field_metadata(Blueprint.t) :: [Blueprint.Document.Field.t]
  defp parse_selected_field_metadata(blueprint) do
    blueprint.operations
    |> Stream.flat_map(&flatten_selections(&1.selections))
    |> Enum.map(&field_to_meta/1)
  end

  @spec flatten_selections([Blueprint.Document.Field.t] | Blueprint.Document.Field.t) :: [Blueprint.Document.Field.t]
  defp flatten_selections([]), do: []

  defp flatten_selections([%Blueprint.Document.Field{} | _] = selections), do:
    selections |> Enum.flat_map(&flatten_selections/1)

  defp flatten_selections(%Blueprint.Document.Field{} = selection), do:
    [selection | flatten_selections(selection.selections)]

  @spec field_to_meta(Blueprint.Document.Field.t) :: Keyword.t
  defp field_to_meta(%Blueprint.Document.Field{schema_node: %Absinthe.Type.Field{__private__: private}}) do
    case Keyword.fetch(private, :meta) do
      :error ->
        []

      {:ok, meta} ->
        meta
    end
  end
end
