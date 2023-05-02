defmodule SchematicTest.Generators do
  @moduledoc """
  Generators for property-based testing
  """

  import Schematic

  @doc """
  Generates structure-less data that has an analogous `Schematic` function. This excludes maps, lists, and tuples.
  """
  def leaf_value() do
    StreamData.one_of([
      StreamData.binary(),
      StreamData.integer(),
      StreamData.boolean(),
      StreamData.constant(nil)
    ])
  end

  def json_value() do
    StreamData.one_of([
      leaf_value(),
      StreamData.map_of(StreamData.binary(), leaf_value()),
      StreamData.list_of(leaf_value())
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

  @doc """
    Generates a `{schematic, data}` tuple where the former describes the latter.

    The generated data will have up to 9 layers of nesting, including the leaf nodes. The matching schematic may
    be significantly less complicated, as there is a chance that a deeply nested map is covered by a schematic
    like `Schematic.map()`.
  """
  def schematic_and_data() do
    StreamData.bind(data(0), fn raw_data ->
      StreamData.constant({schematic_from_data(raw_data) |> Enum.fetch!(1), raw_data})
    end)
  end

  defp data(8) do
    StreamData.one_of([
      StreamData.integer(),
      StreamData.boolean(),
      StreamData.binary(),
      StreamData.constant(nil),
      StreamData.list_of(leaf_value(), max_length: 5) |> StreamData.map(&List.to_tuple/1),
      StreamData.list_of(leaf_value(), max_length: 5),
      StreamData.map_of(
        StreamData.one_of([StreamData.binary(), StreamData.integer()]),
        leaf_value(),
        max_length: 5
      )
    ])
  end

  defp data(depth) do
    StreamData.one_of([
      StreamData.integer(),
      StreamData.boolean(),
      StreamData.binary(),
      StreamData.constant(nil),
      StreamData.list_of(data(depth + 1), max_length: 5) |> StreamData.map(&List.to_tuple/1),
      StreamData.list_of(data(depth + 1), max_length: 5),
      StreamData.map_of(
        StreamData.one_of([StreamData.binary(), StreamData.integer()]),
        data(depth + 1),
        max_length: 5
      )
    ])
  end

  defp schematic_from_data(data) when is_integer(data),
    do: StreamData.member_of([int(), int(data)])

  defp schematic_from_data(data) when is_binary(data),
    do: StreamData.member_of([str(), str(data)])

  defp schematic_from_data(data) when is_boolean(data),
    do: StreamData.member_of([bool(), bool(data)])

  defp schematic_from_data(data) when is_nil(data), do: StreamData.constant(null())

  defp schematic_from_data(data) when is_tuple(data) do
    Tuple.to_list(data)
    |> Enum.map(fn datum -> schematic_from_data(datum) |> Enum.fetch!(1) end)
    |> tuple()
    |> StreamData.constant()
  end

  defp schematic_from_data(data) when is_list(data) do
    StreamData.member_of([
      list(),
      Enum.reduce(data, [], fn datum, acc ->
        [schematic_from_data(datum) |> Enum.fetch!(1) | acc]
      end)
      |> oneof()
      |> list()
    ])
  end

  defp schematic_from_data(data) when is_map(data) do
    schematic_options =
      Enum.reduce(data, {[], []}, fn {datum_key, datum_value}, {key_types, val_types} ->
        {
          [schematic_from_data(datum_key) |> Enum.fetch!(1) | key_types],
          [schematic_from_data(datum_value) |> Enum.fetch!(1) | val_types]
        }
      end)
      |> then(fn {key_types, val_types} ->
        [key_schematic: oneof(key_types), value_schematic: oneof(val_types)]
      end)
      |> map()

    blueprint =
      Enum.reduce(data, %{}, fn {datum_key, datum_value}, acc ->
        Map.put(acc, datum_key, schematic_from_data(datum_value) |> Enum.fetch!(1))
      end)
      |> map()

    StreamData.member_of([schematic_options, blueprint])
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
        StreamData.list_of(leaf_value())

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

      "tuple" ->
        StreamData.constant({})
    end
  end
end
