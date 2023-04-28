defmodule SchematicTest.Generators do
  @moduledoc """
  Generators for property-based testing
  """

  import Schematic

  def json_primitive() do
    StreamData.one_of([
      StreamData.binary(),
      StreamData.integer(),
      StreamData.float(),
      StreamData.boolean(),
      StreamData.constant(nil)
    ])
  end

  def json_value() do
    StreamData.one_of([
      json_primitive(),
      StreamData.map_of(StreamData.binary(), json_primitive()),
      StreamData.list_of(json_primitive())
    ])
  end

  # TODO: find a non-heinous way to generate tuple schematics
  def schematic() do
    [
      int(),
      bool(),
      str(),
      list(),
      Schematic.map(
        key_schematic: str(),
        value_schematic:
          StreamData.member_of([
            str(),
            int(),
            bool()
          ])
      )
    ]
    |> Enum.map(&StreamData.constant/1)
    |> StreamData.one_of()
  end

  def from_schematic(%Schematic{kind: kind}) do
    case kind do
      "integer" ->
        StreamData.integer()

      "string" ->
        StreamData.binary()

      "boolean" ->
        StreamData.boolean()

      "list" ->
        StreamData.list_of(json_primitive())

      "map" ->
        StreamData.map_of(
          StreamData.binary(),
          StreamData.member_of([
            str(),
            int(),
            bool()
          ])
        )

      "tuple" ->
        json_primitive()
        |> StreamData.list_of()
        |> StreamData.map(&List.to_tuple/1)
    end
  end
end