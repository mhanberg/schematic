defmodule SchematicTest.Generators do
  @moduledoc """
  Generators for property-based testing.

  Every public function in this module returns a `StreamData` generator stream that can be used
  directly or composed with other functions from the `StreamData` API.
  """

  import Schematic

  @doc """
    Generates a `{schematic, data}` tuple where the former describes the latter.

    The generated data will have up to 9 layers of nesting, including the leaf nodes.

    The matching schematic may be significantly less complicated, as there is a chance that
    a deeply nested map is covered by a more general schematic like `Schematic.map()`. A matching
    schematic may also be more permissive, allowing unification for more than the given datum,
    such as a datum of `13` generating a schematic like `Schematic.oneof([int(), str()])`.


    ## Options

    * `:using` - a list of `Schematic.kind` values that determines the **only** data types that **should** be generated. See the `Schematic` module for available `kind`s. Defaults to `[]`.
       * e.g. `["null", "integer", "boolean"]`
    * `:excluding` - a list of `Schematic.kind` values that determines the **only** data types that **should not** be generated. See the `Schematic` module for available `kind`s. This option is mutually exclusive with `:using`; if the `:using` option is **not** an empty list then this option is ignored. Defaults to `[]`. 
       * e.g. `["null", "integer", "boolean"]`
  """
  def schematic_and_data(opts \\ []) do
    StreamData.bind(data(0, opts), fn raw_data ->
      StreamData.constant({schematic_from_data(raw_data) |> Enum.fetch!(1), raw_data})
    end)
  end

  defp data(depth, opts \\ [])

  defp data(8, opts) do
    using = Keyword.get(opts, :using, [])
    excluding = Keyword.get(opts, :excluding, [])

    filter =
      case using do
        [] -> {:reject, excluding}
        _ -> {:accept, using}
      end

    ["integer", "boolean", "null", "string", "list", "tuple", "map"]
    |> then(fn kinds ->
      case filter do
        {:reject, excluding} -> Enum.reject(kinds, &Enum.member?(excluding, &1))
        {:accept, using} -> Enum.filter(kinds, &Enum.member?(using, &1))
      end
    end)
    |> Enum.map(fn
      "integer" ->
        StreamData.integer()

      "boolean" ->
        StreamData.boolean()

      "null" ->
        StreamData.constant(nil)

      "string" ->
        StreamData.binary()

      "tuple" ->
        StreamData.list_of(scalar(), max_length: 5) |> StreamData.map(&List.to_tuple/1)

      "list" ->
        StreamData.list_of(scalar(), max_length: 5)

      "map" ->
        StreamData.map_of(
          StreamData.one_of([StreamData.binary(), StreamData.integer()]),
          scalar(),
          max_length: 5
        )
    end)
    |> StreamData.one_of()
  end

  defp data(depth, opts) do
    using = Keyword.get(opts, :using, [])
    excluding = Keyword.get(opts, :excluding, [])

    filter =
      case using do
        [] -> {:reject, excluding}
        _ -> {:accept, using}
      end

    ["integer", "boolean", "null", "string", "list", "tuple", "map"]
    |> then(fn kinds ->
      case filter do
        {:reject, excluding} -> Enum.reject(kinds, &Enum.member?(excluding, &1))
        {:accept, using} -> Enum.filter(kinds, &Enum.member?(using, &1))
      end
    end)
    |> Enum.map(fn
      "integer" ->
        StreamData.integer()

      "boolean" ->
        StreamData.boolean()

      "null" ->
        StreamData.constant(nil)

      "string" ->
        StreamData.binary()

      "tuple" ->
        StreamData.list_of(data(depth + 1), max_length: 5) |> StreamData.map(&List.to_tuple/1)

      "list" ->
        StreamData.list_of(data(depth + 1), max_length: 5)

      "map" ->
        StreamData.map_of(
          StreamData.one_of([StreamData.binary(), StreamData.integer()]),
          data(depth + 1),
          max_length: 5
        )
    end)
    |> StreamData.one_of()
  end

  defp schematic_from_data(data) when is_integer(data),
    do:
      StreamData.member_of([
        int(),
        int(data),
        oneof([int(), simple_schematic() |> Enum.fetch!(1)]),
        oneof([int(data), simple_schematic() |> Enum.fetch!(1)])
      ])

  defp schematic_from_data(data) when is_binary(data),
    do:
      StreamData.member_of([
        str(),
        str(data),
        oneof([str(), simple_schematic() |> Enum.fetch!(1)]),
        oneof([str(data), simple_schematic() |> Enum.fetch!(1)])
      ])

  defp schematic_from_data(data) when is_boolean(data),
    do:
      StreamData.member_of([
        bool(),
        bool(data),
        oneof([bool(), simple_schematic() |> Enum.fetch!(1)]),
        oneof([bool(data), simple_schematic() |> Enum.fetch!(1)])
      ])

  defp schematic_from_data(data) when is_nil(data),
    do: StreamData.member_of([null(), nullable(simple_schematic() |> Enum.fetch!(1))])

  defp schematic_from_data(data) when is_tuple(data) do
    Tuple.to_list(data)
    |> Enum.map(fn datum -> schematic_from_data(datum) |> Enum.fetch!(1) end)
    |> tuple()
    |> StreamData.constant()
  end

  defp schematic_from_data(data) when is_list(data) do
    one_of_schematic =
      Enum.reduce(data, [], fn datum, acc ->
        [schematic_from_data(datum) |> Enum.fetch!(1) | acc]
      end)
      |> oneof()
      |> list()

    StreamData.member_of([
      list(),
      one_of_schematic
    ])
  end

  # TODO: generate schematics that allow for optional keys, and maybe add extra optional keys that aren't present in `data`
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

  @doc """
  Generates structure-less data that has an analogous `Schematic` function. This excludes maps, lists, and tuples.
  """
  def scalar() do
    StreamData.one_of([
      StreamData.binary(),
      StreamData.integer(),
      StreamData.boolean(),
      StreamData.constant(nil)
    ])
  end

  @doc """
  Generator for random, simple `Schematic`s. All `Schematic`s that this is capable of generating are
  the *most permissive version of that data type*, **except** for:
    * `map` `Schematic`s will only accept string keys
    * `tuple` `Schematic`s will only unify with an empty tuple, i.e. `{}`

  For generating more complex schematics with matching data, see `schematic_and_data/1`.

  ## Options

  * `:excluding` - a list of `Schematic.kind` values that should **not** be generated. Defaults to `[]`.
     * e.g. `["null", "int"]`
  """
  def simple_schematic(opts \\ []) do
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
            tuple([]),
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
  Generates data that will unify with a schematic generated by `simple_schematic/1`. 

  For generating more complex schematics with matching data, see `schematic_and_data/1`.
  """
  def from_simple_schematic(%Schematic{kind: kind}) do
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
        StreamData.list_of(scalar())

      "map" ->
        StreamData.map_of(
          StreamData.binary(),
          StreamData.member_of([
            scalar(),
            StreamData.list_of(scalar()),
            StreamData.map_of(StreamData.binary(), scalar()),
          ])
        )

      "tuple" ->
        StreamData.constant({})
    end
  end
end
