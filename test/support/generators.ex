defmodule SchematicTest.Generators do
  @moduledoc """
  `StreamData` generators.
  """
  unless macro_exported?(Kernel, :then, 2) do
    defmacrop then(value, fun) do
      quote do
        unquote(fun).(unquote(value))
      end
    end
  end

  @doc """
  Generates a `{schematic, data}` tuple where the former specifies the latter.

  The generated data will have up to 9 layers of nesting, including the leaf nodes.

  The matching schematic may be significantly less complicated, as there is a chance that
  a deeply nested map is covered by a more general schematic like `Schematic.map()`. A matching
  schematic may also be more permissive, allowing unification for more than the given datum,
  such as a datum of `13` generating a schematic like `Schematic.oneof([Schematic.int(), Schematic.str()])`.


  ## Options

  * `:using` - a list of `Schematic.kind` values that determines the data types that will be generated. See the `Schematic` module for available `kind`s. Defaults to `[]`.
     * e.g. `["null", "integer", "boolean"]`
  * `:excluding` - a list of `Schematic.kind` values that determines the data types that will not be generated. See the `Schematic` module for available `kind`s. This option is mutually exclusive with `:using`. Defaults to `[]`.
     * e.g. `["null", "integer", "boolean"]`
  """
  def schematic_and_data(opts \\ []) do
    StreamData.bind(data(0, opts), fn raw_data ->
      StreamData.constant({schematic_from_data(raw_data) |> Enum.fetch!(1), raw_data})
    end)
  end

  defp data(depth, opts \\ []) do
    using = Keyword.get(opts, :using, [])
    excluding = Keyword.get(opts, :excluding, [])

    ["integer", "float", "boolean", "null", "string", "list", "tuple", "map", "atom"]
    |> then(fn kinds ->
      if Enum.empty?(using) do
        Enum.reject(kinds, &Enum.member?(excluding, &1))
      else
        Enum.filter(kinds, &Enum.member?(using, &1))
      end
    end)
    |> Enum.map(fn
      "integer" ->
        StreamData.integer()

      "float" ->
        StreamData.float()

      "atom" ->
        atom()

      "boolean" ->
        StreamData.boolean()

      "null" ->
        StreamData.constant(nil)

      "string" ->
        StreamData.string(:ascii, max_length: 10)

      "tuple" ->
        case depth + 1 do
          8 -> scalar()
          depth -> data(depth)
        end
        |> StreamData.list_of(max_length: 5)
        |> StreamData.map(&List.to_tuple/1)

      "list" ->
        case depth + 1 do
          8 -> scalar()
          depth -> data(depth)
        end
        |> StreamData.list_of(max_length: 5)

      "map" ->
        StreamData.map_of(
          StreamData.one_of([StreamData.string(:ascii, max_length: 10), StreamData.integer()]),
          case depth + 1 do
            8 -> scalar()
            depth -> data(depth)
          end,
          min_length: 1,
          max_length: 5
        )
    end)
    |> StreamData.one_of()
  end

  defp schematic_from_data(data) when is_integer(data) do
    StreamData.member_of([
      Schematic.int(),
      data,
      Schematic.oneof([Schematic.int(), simple_schematic() |> Enum.fetch!(1)]),
      Schematic.oneof([data, simple_schematic() |> Enum.fetch!(1)])
    ])
  end

  defp schematic_from_data(data) when is_atom(data) do
    StreamData.member_of([
      data,
      Schematic.oneof([data, simple_schematic() |> Enum.fetch!(1)])
    ])
  end

  defp schematic_from_data(data) when is_float(data) do
    StreamData.member_of([
      Schematic.float(),
      data,
      Schematic.oneof([Schematic.float(), simple_schematic() |> Enum.fetch!(1)]),
      Schematic.oneof([data, simple_schematic() |> Enum.fetch!(1)])
    ])
  end

  defp schematic_from_data(data) when is_binary(data) do
    StreamData.member_of([
      Schematic.str(),
      data,
      Schematic.oneof([Schematic.str(), simple_schematic() |> Enum.fetch!(1)]),
      Schematic.oneof([data, simple_schematic() |> Enum.fetch!(1)])
    ])
  end

  defp schematic_from_data(data) when is_boolean(data) do
    StreamData.member_of([
      Schematic.bool(),
      data,
      Schematic.oneof([Schematic.bool(), simple_schematic() |> Enum.fetch!(1)]),
      Schematic.oneof([data, simple_schematic() |> Enum.fetch!(1)])
    ])
  end

  defp schematic_from_data(data) when is_nil(data) do
    StreamData.member_of([
      nil,
      Schematic.nullable(simple_schematic() |> Enum.fetch!(1))
    ])
  end

  defp schematic_from_data(data) when is_tuple(data) do
    Tuple.to_list(data)
    |> Enum.map(fn datum -> schematic_from_data(datum) |> Enum.fetch!(1) end)
    |> Schematic.tuple()
    |> StreamData.constant()
  end

  defp schematic_from_data(data) when is_list(data) do
    one_of_schematic =
      Enum.reduce(data, [], fn datum, acc ->
        [schematic_from_data(datum) |> Enum.fetch!(1) | acc]
      end)
      |> Schematic.oneof()
      |> Schematic.list()

    StreamData.member_of([
      Schematic.list(),
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
        [key_schematic: Schematic.oneof(key_types), value_schematic: Schematic.oneof(val_types)]
      end)
      |> Schematic.map()

    blueprint =
      Enum.reduce(data, %{}, fn {datum_key, datum_value}, acc ->
        Map.put(acc, datum_key, schematic_from_data(datum_value) |> Enum.fetch!(1))
      end)
      |> Schematic.map()

    StreamData.member_of([schematic_options, blueprint])
  end

  @doc """
  Generates non-compound data that has an analogous `Schematic` function. This excludes maps, lists, and tuples.
  """
  def scalar() do
    StreamData.one_of([
      StreamData.binary(),
      atom(),
      StreamData.integer(),
      StreamData.float(),
      StreamData.boolean(),
      StreamData.constant(nil)
    ])
  end

  defp atom() do
    StreamData.map(StreamData.string(:ascii, max_length: 10), &String.to_atom/1)
  end

  @doc """
  Generator for random, simple `schematic`s. All `schematic`s that this is capable of generating are
  the *most permissive version of that data type*, **except** for:
    * `map` `schematic`s will only accept string keys
    * `tuple` `schematic`s will only unify with an empty tuple, i.e. `{}`

  For generating more complex schematics with matching data, see `schematic_and_data/1`.

  ## Options

  * `:excluding` - a list of `Schematic.kind` values that should **not** be generated. Defaults to `[]`.
     * e.g. `["null", "int"]`
  """
  def simple_schematic(opts \\ []) do
    excluding = Keyword.get(opts, :excluding, [])

    [
      Schematic.int(),
      Schematic.float(),
      Schematic.bool(),
      Schematic.str(),
      nil,
      Schematic.tuple([]),
      Schematic.list(),
      Schematic.map(
        key_schematic: Schematic.str(),
        value_schematic:
          StreamData.member_of([
            Schematic.str(),
            Schematic.int(),
            Schematic.float(),
            Schematic.bool(),
            nil,
            Schematic.tuple([]),
            Schematic.list(),
            Schematic.map()
          ])
      )
    ]
    |> Enum.filter(fn
      %Schematic{kind: kind} ->
        kind not in excluding

      nil ->
        "null" not in excluding
    end)
    |> Enum.map(&StreamData.constant/1)
    |> StreamData.one_of()
  end

  @doc """
  Generates data that will unify with a schematic generated by `simple_schematic/1`.

  For generating more complex schematics with matching data, see `schematic_and_data/1`.
  """
  def from_simple_schematic(schematic) do
    case Schematic.Unification.kind(schematic) do
      "integer" ->
        StreamData.integer()

      "float" ->
        StreamData.float()

      "string" ->
        StreamData.binary()

      "atom" ->
        StreamData.atom(:alphanumeric)

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
            StreamData.map_of(StreamData.binary(), scalar())
          ])
        )

      "tuple" ->
        StreamData.constant({})
    end
  end
end
