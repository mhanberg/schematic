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
  @doc """
  Generator for random `Schematic`s.

  ## Options

  * `:excluding` - a list of `Schematic.kind` values that should **not** be generated. Defaults to `[]`.
     * e.g. `["null", "int"]`
  """
  def schematic(opts \\ []) do
    excluding = Keyword.get(opts, :excluding, [])

    [
      int(),
      bool(),
      str(),
      null(),
      tuple([]),
      list(),
      map(
        key_schematic: str(),
        value_schematic:
          StreamData.member_of([
            str(),
            int(),
            bool(),
            null(),
            list(),
            map()
          ])
      )
    ]
    |> Enum.filter(fn %Schematic{kind: kind} -> kind not in excluding end)
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

      "null" ->
        StreamData.constant(nil)

      "list" ->
        StreamData.list_of(json_primitive())

      "map" ->
        StreamData.map_of(
          StreamData.binary(),
          StreamData.member_of([
            str(),
            int(),
            bool(),
            null(),
            list(),
            map()
          ])
        )

      "tuple" -> StreamData.constant({})
    end
  end
end
