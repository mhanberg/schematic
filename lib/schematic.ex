defmodule Schematic do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  defstruct [:unify, :kind, :message]

  @typedoc """
  The Schematic data structure.

  This data structure is meant to be opaque to the user, but you can create your own for super niche use cases. But backwards compatiblility of this data structure is not guaranteed.
  """
  @opaque t :: %__MODULE__{
            unify: (term(), :up | :down -> {:ok, term()} | {:error, String.t() | [String.t()]}),
            kind: String.t(),
            message: function() | nil
          }

  @typedoc """
  A lazy reference to a schematic, used to define recursive schematics.
  """
  @type lazy_schematic :: {atom(), atom(), list(any())}

  unless macro_exported?(Kernel, :then, 2) do
    defmacrop then(value, fun) do
      quote do
        unquote(fun).(unquote(value))
      end
    end
  end

  defmodule OptionalKey do
    @enforce_keys [:key]
    defstruct [:key]

    @opaque t :: %__MODULE__{
              key: {any(), any()} | any()
            }
  end

  @doc """
  Specifies that the data can be **any**thing.

  ## Usage

  ```elixir
  iex> schematic = any()
  iex> {:ok, "hi!"} = unify(schematic, "hi!")
  iex> {:ok, [:one, :two, :three]} = unify(schematic, [:one, :two, :three])
  iex> {:ok, true} = unify(schematic, true)
  ```
  """
  @spec any() :: t()
  def any() do
    %Schematic{kind: "any", unify: telemetry_wrap(:any, %{}, fn x, _dir -> {:ok, x} end)}
  end

  @doc """
  Specifies that the data can be `nil`.

  ## Usage

  ```elixir
  iex> schematic = null()
  iex> {:ok, nil} = unify(schematic, nil)
  iex> {:error, "expected null"} = unify(schematic, "hi!")
  ```
  """
  @spec null() :: t()
  def null() do
    %Schematic{
      kind: "null",
      message: fn -> "null" end,
      unify:
        telemetry_wrap(:null, %{}, fn
          nil, _dir -> {:ok, nil}
          _input, _dir -> {:error, "expected null"}
        end)
    }
  end

  @doc """
  Shortcut for specifiying that a schematic can be either null or the schematic.

  ## Usage

  ```elixir
  iex> schematic = nullable(str())
  iex> {:ok, nil} = unify(schematic, nil)
  iex> {:ok, "hi!"} = unify(schematic, "hi!")
  iex> {:error, "expected either null or a string"} = unify(schematic, :boom)
  ```
  """
  @spec nullable(t() | lazy_schematic()) :: t()
  def nullable(schematic) do
    oneof([null(), schematic])
  end

  @doc """
  Specifies that the data is a boolean or a specific boolean.

  ## Usage

  Any boolean.

  ```elixir
  iex> schematic = bool()
  iex> {:ok, true} = unify(schematic, true)
  iex> {:ok, false} = unify(schematic, false)
  iex> {:error, "expected a boolean"} = unify(schematic, :boom)
  ```

  A boolean literal.

  ```elixir
  iex> schematic = bool(true)
  iex> {:ok, true} = unify(schematic, true)
  iex> {:error, "expected true"} = unify(schematic, :boom)
  ```
  """
  @spec bool(boolean() | nil) :: t()
  def bool(literal \\ nil) do
    message = fn ->
      if is_boolean(literal) do
        "#{inspect(literal)}"
      else
        "a boolean"
      end
    end

    %Schematic{
      kind: "boolean",
      message: message,
      unify:
        telemetry_wrap(:bool, %{literal: not is_nil(literal)}, fn input, _dir ->
          # FIXME: this is ugly
          cond do
            is_boolean(literal) ->
              if is_boolean(input) && input == literal do
                {:ok, input}
              else
                {:error, ~s|expected #{message.()}|}
              end

            is_boolean(input) ->
              {:ok, input}

            true ->
              {:error, "expected #{message.()}"}
          end
        end)
    }
  end

  @doc """
  Specifies that the data is a string or a specific string.

  ## Usage

  Any string.

  ```elixir
  iex> schematic = str()
  iex> {:ok, "hi!"} = unify(schematic, "hi!")
  iex> {:error, "expected a string"} = unify(schematic, :boom)
  ```

  A string literal.

  ```elixir
  iex> schematic = str("I 💜 Elixir")
  iex> {:ok, "I 💜 Elixir"} = unify(schematic,  "I 💜 Elixir")
  iex> {:error, ~s|expected the literal string "I 💜 Elixir"|} = unify(schematic, "I love Ruby")
  ```
  """
  @spec str(String.t() | nil) :: t()
  def str(literal \\ nil) do
    message = fn ->
      if literal do
        "the literal string #{inspect(literal)}"
      else
        "a string"
      end
    end

    %Schematic{
      kind: "string",
      message: message,
      unify:
        telemetry_wrap(:str, %{literal: not is_nil(literal)}, fn input, _dir ->
          # FIXME: this is ugly
          cond do
            is_binary(literal) ->
              if is_binary(input) && input == literal do
                {:ok, input}
              else
                {:error, ~s|expected #{message.()}|}
              end

            is_binary(input) ->
              {:ok, input}

            true ->
              {:error, "expected #{message.()}"}
          end
        end)
    }
  end

  @doc """
  Specifies that the data is an integer or a specific integer.

  ## Usage

  Any integer.

  ```elixir
  iex> schematic = int()
  iex> {:ok, 99} = unify(schematic, 99)
  iex> {:error, "expected an integer"} = unify(schematic, :boom)
  ```

  A integer literal.

  ```elixir
  iex> schematic = int(99)
  iex> {:ok, 99} = unify(schematic,  99)
  iex> {:error, ~s|expected the literal integer 99|} = unify(schematic, :ninetynine)
  ```
  """
  @spec int(integer() | nil) :: t()
  def int(literal \\ nil) do
    message = fn ->
      if literal do
        "the literal integer #{inspect(literal)}"
      else
        "an integer"
      end
    end

    %Schematic{
      kind: "integer",
      message: message,
      unify:
        telemetry_wrap(:int, %{literal: not is_nil(literal)}, fn input, _dir ->
          # FIXME: this is ugly
          cond do
            is_integer(literal) ->
              if is_integer(input) && input == literal do
                {:ok, input}
              else
                {:error, ~s|expected #{message.()}|}
              end

            is_integer(input) ->
              {:ok, input}

            true ->
              {:error, "expected #{message.()}"}
          end
        end)
    }
  end

  @doc """
  Specifies that the data is a list of any size and contains anything.

  ## Usage

  ```elixir
  iex> schematic = list()
  iex> {:ok, ["one", 2, :three]} = unify(schematic, ["one", 2, :three])
  iex> {:error, "expected a list"} = unify(schematic, :hi)
  ```
  """
  @spec list() :: t()
  def list() do
    message = fn -> "a list" end

    %Schematic{
      kind: "list",
      message: message,
      unify:
        telemetry_wrap(:list, %{}, fn input, _dir ->
          if is_list(input) do
            {:ok, input}
          else
            {:error, ~s|expected #{message.()}|}
          end
        end)
    }
  end

  @doc """
  Specifies that the data is a list whose items unify to the given schematic.

  ## Usage

  ```elixir
  iex> schematic = list(oneof([str(), int()]))
  iex> {:ok, ["one", 2, "three"]} = unify(schematic, ["one", 2, "three"])
  iex> {:error, "expected a list of either a string or an integer"} = unify(schematic, ["one", 2, :three])
  ```
  """
  @spec list(t() | lazy_schematic()) :: t()
  def list(schematic) do
    schematic = fn ->
      case schematic do
        {mod, func, args} ->
          apply(mod, func, args)

        schematic ->
          schematic
      end
    end

    message = fn -> "a list of #{schematic.().message.()}" end

    %Schematic{
      kind: "list",
      message: message,
      unify:
        telemetry_wrap(:list, %{}, fn input, dir ->
          if is_list(input) do
            Enum.reduce_while(input, {:ok, []}, fn el, {:ok, acc} ->
              case schematic.().unify.(el, dir) do
                {:ok, output} ->
                  {:cont, {:ok, [output | acc]}}

                {:error, _error} ->
                  {:halt, {:error, ~s|expected #{message.()}|}}
              end
            end)
            |> then(fn
              {:ok, result} ->
                {:ok, Enum.reverse(result)}

              error ->
                error
            end)
          else
            {:error, ~s|expected a list|}
          end
        end)
    }
  end

  @doc """
  Specifies that the data is a tuple of the given length where each element unifies to the schematic in the same position.

  ## Usage

  ```elixir
  iex> schematic = Schematic.tuple([str(), int()])
  iex> {:ok, {"one", 2}} = unify(schematic, {"one", 2})
  iex> {:error, "expected a tuple of {a string, an integer}"} = unify(schematic, {1, "two"})
  ```

  ### Options

  * `:from` - Either `:tuple` or `:list`. Defaults to `:tuple`.

  ```elixir
  iex> schematic = tuple([str(), int()], from: :list)
  iex> {:ok, {"one", 2}} = unify(schematic, ["one", 2])
  iex> {:error, "expected a list of {a string, an integer}"} = unify(schematic, [1, "two"])
  ```
  """
  @spec tuple([t() | lazy_schematic()], Keyword.t()) :: t()
  def tuple(schematics, opts \\ []) do
    from = Keyword.get(opts, :from, :tuple)
    message = fn -> "a #{from} of {#{Enum.map_join(schematics, ", ", & &1.message.())}}" end

    {condition, to_list, length} =
      case from do
        :list ->
          {&is_list/1, &Function.identity/1, &Enum.count/1}

        :tuple ->
          {&is_tuple/1, &Tuple.to_list/1, &tuple_size/1}
      end

    %Schematic{
      kind: "tuple",
      message: message,
      unify: fn input, dir ->
        if condition.(input) and length.(input) == Enum.count(schematics) do
          input
          |> to_list.()
          |> Enum.with_index()
          |> Enum.reduce_while({:ok, []}, fn {el, idx}, {:ok, acc} ->
            case Enum.at(schematics, idx).unify.(el, dir) do
              {:ok, output} ->
                {:cont, {:ok, [output | acc]}}

              {:error, _error} ->
                {:halt, {:error, ~s|expected #{message.()}|}}
            end
          end)
          |> then(fn
            {:ok, result} ->
              {:ok, result |> Enum.reverse() |> List.to_tuple()}

            error ->
              error
          end)
        else
          {:error, ~s|expected #{message.()}|}
        end
      end
    }
  end

  @doc """
  Specifies that the data is a map with the given keys (literal values) that unify to the provided blueprint.

  Unification errors for keys are returned in a map with the key as the key and the value as the error.

  * Map schematics serve as a way to permit certain keys and discard all others.
  * Keys are non-nullable unless the value schematic is marked with `nullable/1`. This allows the value of the key to be nil as well as the key to be absent from the source data.
  * Keys are considered required unless tagged with `optional/1`. This allows the entire key to be absent from the source data. If the key is present, it must unify according to the given schematic.

  ## Basic Usage

  The most basic map schematic can look like the following.

  ```elixir
  iex> schematic = map(%{
  ...>   "league" => oneof([str("NBA"), str("MLB"), str("NFL")]),
  ...> })
  iex> # ignores the `"team"` key
  iex> {:ok, %{"league" => "NBA"}} == unify(schematic, %{"league" => "NBA", "team" => "Chicago Bulls"})
  true
  iex> {:error,
  ...>   %{
  ...>     "league" =>
  ...>     ~s|expected either the literal string "NBA", the literal string "MLB", or the literal string "NFL"|
  ...>   }} = unify(schematic, %{"league" => "NHL"})
  ```

  ## With a permissive amp

  If you want to _only_ check that the data is a map, but not the shape, you can use `map/0`.

  ```elixir
  iex> schematic = map()
  iex> {:ok, %{"league" => "NBA"}} = unify(schematic, %{"league" => "NBA"})
  ```

  ## With `nullable/1`

  Marking a key as nullable using `nullable/1`.

  This means the value of the key can be nil as well as omitting the key entirely. The unified output will always contain the key.

  ```elixir
  iex> schematic = map(%{
  ...>   "title" => str(),
  ...>   "description" => nullable(str())
  ...> })
  iex> {:ok, %{"title" => "Elixir 101", "description" => nil}} = unify(schematic, %{"title" => "Elixir 101", "description" => nil})
  iex> {:ok, %{"title" => "Elixir 101", "description" => nil}} = unify(schematic, %{"title" => "Elixir 101"})
  iex> {:ok, %{"title" => "Elixir 101", "description" => nil}} = dump(schematic, %{"title" => "Elixir 101"})
  ```

  ## With `optional/1`

  Marking a key as optional using `optional/1`.

  This means that you can omit the key from the input and that the unified output will not contain the key if it wasn't in the input.

  If the key _is_ provided, it must unify according to the given schematic.

  Likewise, using `dump/2` will also omit that key.

  ```elixir
  iex> schematic = map(%{
  ...>   "title" => str(),
  ...>   optional("description") => str()
  ...> })
  iex> {:ok, %{"title" => "Elixir 101", "description" =>  "An amazing programming course."}} = unify(schematic, %{"title" => "Elixir 101", "description" => "An amazing programming course."})
  iex> {:ok, %{"title" => "Elixir 101"}} = unify(schematic, %{"title" => "Elixir 101"})
  iex> {:ok, %{"title" => "Elixir 101"}} = dump(schematic, %{"title" => "Elixir 101"})
  ```

  ## With `:keys` and `:values`

  Instead of passing a blueprint, which specifies keys and values, you can pass a `:keys` and `:values` options which provide schematic that all keys and values in the input must unify to.

  ```elixir
  iex> schematic = map(keys: str(), values: oneof([str(), int()]))
  iex> {:ok, %{"type" => "big", "quantity" => 99}} = unify(schematic, %{"type" => "big", "quantity" => 99})
  iex> {:error, %{"quantity" => "expected either a string or an integer"}} = unify(schematic, %{"type" => "big", "quantity" => [99]})
  ```

  ## Transforming Keys

  During unification, key transformation can be performed if it is specified in the schematic.

  You can specify a key as a 2-tuple with the first element being the input key and the second element being the output key. When calling `dump/2`, the key will be turned from the output key back to the input key (and will also be revalidated).

  This is useful for transforming string keys to atom keys as well as camelCase keys to snake_case keys.

  Key transformation can also be used when declaring an optional key with `optional/1`.

  ```elixir
  iex> schematic = map(%{
  ...>   {"teamName", :team_name} => str()
  ...> })
  iex> {:ok, %{team_name: "Chicago Bulls"}} = unify(schematic, %{"teamName" => "Chicago Bulls"})
  iex> {:ok, %{"teamName" => "Chicago Bulls"}} = dump(schematic, %{team_name: "Chicago Bulls"})
  ```

  ## Recursive Schematics

  One can define schematics that specify keys whose values are themselves.

  For this to be possible, recursive schematics must terminate some way. This can be achienved by specifying those keys as `optional/1` or within a `oneof/1` schematic.

  Recursive schematics are specified as a MFA tuple, `t:lazy_schematic/0`.

  ```elixir
  iex> defmodule Tree do
  ...>   import Schematic
  ...>
  ...>   def schematic() do
  ...>     map(%{values: list(Tree.branch())})
  ...>   end
  ...>
  ...>   def branch() do
  ...>     map(%{
  ...>       values: list(oneof([Tree.leaf(), {__MODULE__, :branch, []}]))
  ...>     })
  ...>   end
  ...>
  ...>   def leaf() do
  ...>     map(%{
  ...>       value: str()
  ...>     })
  ...>   end
  ...> end
  iex> input = %{
  ...>   type: "root",
  ...>   values: [
  ...>     %{
  ...>       type: "branch",
  ...>       values: [
  ...>         %{
  ...>           type: "leaf",
  ...>           value: "i'm a leaf"
  ...>         },
  ...>         %{
  ...>           type: "branch",
  ...>           values: [
  ...>             %{
  ...>               type: "leaf",
  ...>               value: "i'm another leaf"
  ...>             }
  ...>           ]
  ...>         }
  ...>       ]
  ...>     }
  ...>   ]
  ...> }
  iex> unify(SchematicTest.Tree.schematic(), input)
  {:ok, %{values: [%{values: [%{value: "i'm a leaf"}, %{values: [%{value: "i'm another leaf"}]}]}]}}
  ```
  """

  @typedoc "Map blueprint key."
  @type map_blueprint_key :: OptionalKey.t() | any()

  @typedoc "Map blueprint value."
  @type map_blueprint_value :: t() | lazy_schematic()

  @typedoc """
  The blueprint used to specify a map schematic.
  """
  @type map_blueprint :: %{map_blueprint_key() => map_blueprint_value()}

  @spec map(%{map_blueprint_key() => map_blueprint_value()} | Keyword.t()) :: t()
  def map(blueprint_or_opts \\ [])

  def map(blueprint) when is_map(blueprint) do
    %Schematic{
      kind: "map",
      message: fn -> "a map" end,
      unify:
        telemetry_wrap(:map, %{style: :blueprint}, fn input, dir ->
          if is_map(input) do
            bp_keys = Map.keys(blueprint)

            Enum.reduce(
              bp_keys,
              [ok: %{}, errors: %{}],
              fn bpk, [{:ok, acc}, {:errors, errors}] ->
                schematic =
                  case blueprint[bpk] do
                    {mod, func, args} ->
                      apply(mod, func, args)

                    schematic ->
                      schematic
                  end

                key = with %OptionalKey{key: key} <- bpk, do: key
                {from_key, to_key} = with key when not is_tuple(key) <- key, do: {key, key}

                {from_key, to_key} =
                  case dir do
                    :to -> {from_key, to_key}
                    :from -> {to_key, from_key}
                  end

                if not Map.has_key?(input, from_key) and match?(%OptionalKey{}, bpk) do
                  [{:ok, acc}, {:errors, errors}]
                else
                  case schematic.unify.(input[from_key], dir) do
                    {:ok, output} ->
                      acc =
                        acc
                        |> Map.put(to_key, output)

                      [{:ok, acc}, {:errors, errors}]

                    {:error, error} ->
                      # NOTE: in the case of schemas, an optional key will exist because structs always
                      # have all of their fields. So if they don't unify **and**, the key is optional, and
                      # the value is nil, we can assume the schematic did not allow nil, and we can omit
                      # the key from the dump.
                      if input[from_key] == nil and match?(%OptionalKey{}, bpk) do
                        [{:ok, acc}, {:errors, errors}]
                      else
                        [{:ok, acc}, {:errors, Map.put(errors, from_key, error)}]
                      end
                  end
                end
              end
            )
            |> then(fn
              [ok: output, errors: e] when map_size(e) == 0 ->
                {:ok, output}

              [ok: _output, errors: errors] ->
                {:error, errors}
            end)
          else
            {:error, "expected a map"}
          end
        end)
    }
  end

  def map(opts) when is_list(opts) do
    key_schematic = Keyword.get(opts, :keys, any())
    value_schematic = Keyword.get(opts, :values, any())

    %Schematic{
      kind: "map",
      message: fn -> "a map" end,
      unify:
        telemetry_wrap(:map, %{style: :open}, fn input, dir ->
          if is_map(input) do
            Enum.reduce(
              Map.keys(input),
              [ok: %{}, errors: %{}],
              fn input_key, [{:ok, acc}, {:errors, errors}] ->
                case key_schematic.unify.(input_key, dir) do
                  {:ok, key_output} ->
                    case value_schematic.unify.(input[input_key], dir) do
                      {:ok, value_output} ->
                        [{:ok, Map.put(acc, key_output, value_output)}, {:errors, errors}]

                      {:error, error} ->
                        [{:ok, acc}, {:errors, Map.put(errors, input_key, error)}]
                    end

                  {:error, _error} ->
                    # NOTE: we pass just ignore keys which non conforming keys
                    [{:ok, acc}, {:errors, errors}]
                end
              end
            )
            |> then(fn
              [ok: output, errors: e] when map_size(e) == 0 ->
                {:ok, output}

              [ok: _output, errors: errors] ->
                {:error, errors}
            end)
          else
            {:error, "expected a map"}
          end
        end)
    }
  end

  @doc """
  Specifies a `map/1` schematic that is then hydrated into a struct.

  Works the same as the `map/1` schematic, but will also automatically transform all keys from string keys to atom keys if a key conversion is not already specified.

  Since this schematic hydrates a struct, it is also only capable of having atom keys in the output, whereas a normal map can have arbitrary terms as the key.

  ```elixir
  iex> schematic =
  ...>   schema(HTTPRequest, %{
  ...>     method: oneof([str("POST"), str("PUT"), str("PATCH")]),
  ...>     body: str()
  ...>   })
  iex> {:ok, %HTTPRequest{method: "POST", body: ~s|{"name": "Peter"}|}} = unify(schematic, %{"method" => "POST", "body" => ~s|{"name": "Peter"}|})
  iex> {:ok, %{"method" => "POST", "body" => ~s|{"name": "Peter"}|}} = dump(schematic, %HTTPRequest{method: "POST", body: ~s|{"name": "Peter"}|})
  ```
  """

  @typedoc "Schema blueprint key."
  @type schema_blueprint_key :: OptionalKey.t() | atom()

  @typedoc "Schema blueprint value."
  @type schema_blueprint_value :: t() | lazy_schematic()

  @typedoc """
  The blueprint used to specify a schema schematic.
  """
  @type schema_blueprint :: %{schema_blueprint_key() => schema_blueprint_value()}

  @spec schema(atom(), schema_blueprint()) :: t()
  def schema(mod, blueprint) do
    schematic =
      map(
        Map.new(blueprint, fn
          {%OptionalKey{key: k}, v} when is_atom(k) ->
            {%OptionalKey{key: {to_string(k), k}}, v}

          {k, v} when is_atom(k) ->
            {{to_string(k), k}, v}

          kv ->
            kv
        end)
      )

    %Schematic{
      kind: "#{mod}",
      message: fn -> "a %#{String.replace(to_string(mod), "Elixir.", "")}{}" end,
      unify:
        telemetry_wrap(:schema, %{mod: mod}, fn input, dir ->
          case dir do
            :to ->
              with {:ok, output} <- schematic.unify.(input, :to) do
                {:ok, struct(mod, output)}
              end

            :from ->
              with {:ok, input} <- struct?(input, mod),
                   {:ok, output} <- schematic.unify.(Map.from_struct(input), :from) do
                {:ok, output}
              end
          end
        end)
    }
  end

  defp struct?(%struct{} = input, mod) when struct == mod do
    {:ok, input}
  end

  defp struct?(_input, mod) do
    {:error, "expected a #{mod} struct"}
  end

  @doc """
  A utility for creating custom schematics.

  The `raw/1` schematic is useful for creating schematics that unify the _values_ of the inputs, rather than just the shape.

  ## Options

  * `:message` - a custom error message. Defaults to `"is invalid"`.
  * `:transformer` - a function that takes the input and the unification direction and must return the desired value. Defaults to `fn input, _dir -> input end`.

  ## Basic Usage

  ```elixir
  iex> schematic = all([int(), raw(fn i -> i > 10 end, message: "must be greater than 10")])
  iex> {:ok, 11} = unify(schematic, 11)
  iex> {:error, ["must be greater than 10"]} = unify(schematic, 9)
  ```

  ## Advanced Usage

  If your data requires different validations for unification and dumping, then you can pass a 2-arity function (instead of a 1-arity function) and the second parameter will be the direction.

  This concept also applies to the `:transform` option.

  ```elixir
  iex> schematic =
  ...>   raw(
  ...>     fn
  ...>       n, :to -> is_list(n) and length(n) == 3
  ...>       n, :from -> is_tuple(n) and tuple_size(n) == 3
  ...>     end,
  ...>     message: "must be a tuple of size 3",
  ...>     transform: fn
  ...>       input, :to ->
  ...>         List.to_tuple(input)
  ...>       input, :from ->
  ...>         Tuple.to_list(input)
  ...>     end
  ...>   )
  iex> {:ok, {"one", "two", 3}} = unify(schematic, ["one", "two", 3])
  iex> {:error, "must be a tuple of size 3"} = unify(schematic, ["not", "big"])
  iex> {:ok, ["one", "two", 3]} = dump(schematic, {"one", "two", 3})
  ```
  """
  @spec raw((any() -> boolean()) | (any(), :up | :down -> boolean()), [tuple()]) :: t()
  def raw(function, opts \\ []) do
    message = fn -> Keyword.get(opts, :message, "is invalid") end
    transformer = Keyword.get(opts, :transform, fn input, _dir -> input end)

    %Schematic{
      kind: "function",
      message: message,
      unify:
        telemetry_wrap(:raw, %{}, fn input, dir ->
          if convert_to_two_arity(function).(input, dir) do
            {:ok, convert_to_two_arity(transformer).(input, dir)}
          else
            {:error, message.()}
          end
        end)
    }
  end

  defp convert_to_two_arity(f) when is_function(f, 1) do
    fn a, _ -> f.(a) end
  end

  defp convert_to_two_arity(f) when is_function(f, 2) do
    f
  end

  @doc """
  Specifies that the data must unify with all of the given schematics.

  On error, returns a list of validation messages.

  If a schematic raises an exception, it is caught and the error `"is invalid"` is returned.

  ```elixir
  iex> schematic = all([int(), raw(&Kernel.<(&1, 10), message: "must be less than 10"), raw(&(Kernel.rem(&1, 2) == 0), message: "must be divisible by 2")])
  iex> {:ok, 8} = unify(schematic, 8)
  iex> {:error, ["must be less than 10", "must be divisible by 2"]} = unify(schematic, 15)
  iex> {:error, ["expected an integer", "must be less than 10", "is invalid"]} = unify(schematic, "15")
  ```
  """
  @spec all([t()]) :: t()
  def all(schematics) when is_list(schematics) do
    message = fn -> Enum.map(schematics, & &1.message) end

    %Schematic{
      kind: "all",
      message: message,
      unify:
        telemetry_wrap(:all, %{}, fn input, dir ->
          errors =
            for schematic <- schematics,
                {result, message} = __try__(fn -> schematic.unify.(input, dir) end),
                result == :error do
              message
            end

          if Enum.empty?(errors) do
            {:ok, input}
          else
            {:error, errors}
          end
        end)
    }
  end

  defp __try__(callback) do
    callback.()
  rescue
    _ ->
      {:error, "is invalid"}
  end

  @doc """
  Specifies that the data unifies to one of the given schematics.

  Can be called with a list of schematics or a function.

  ## With a list

  When called with a list of schematics, they will be traversed during unification and the first one to unify will be returned. If none of them unify, then an error is returned.

  ```elixir
  iex> team = map(%{name: str(), league: str()})
  iex> player = map(%{name: str(), team: str()})
  iex> schematic = oneof([team, player])
  iex> {:ok, %{name: "Indiana Pacers", league: "NBA"}} = unify(schematic, %{name: "Indiana Pacers", league: "NBA"})
  iex> {:ok, %{name: "George Hill", team: "Indiana Pacers"}} = unify(schematic, %{name: "George Hill", team: "Indiana Pacers"})
  iex> {:error, "expected either a map or a map"} = unify(schematic, %{name: "NBA", sport: "basketball"})
  ```

  ## With a function

  When called with a function, the input is passed as the only parameter. This can be used to dispach to a specific schematic. This is a performance optimization, as you can dispatch to a specific schematic rather than traversing all of them.

  ```elixir
  iex> schematic = oneof(fn
  ...>   %{type: "team"} -> map(%{name: str(), league: str()})
  ...>   %{type: "player"} -> map(%{name: str(), team: str()})
  ...>   _ -> {:error, "expected either a player or a team"}
  ...> end)
  iex> {:ok, %{name: "Indiana Pacers", league: "NBA"}} = unify(schematic, %{type: "team", name: "Indiana Pacers", league: "NBA"})
  iex> {:ok, %{name: "George Hill", team: "Indiana Pacers"}} = unify(schematic, %{type: "player", name: "George Hill", team: "Indiana Pacers"})
  iex> {:error, "expected either a player or a team"} = unify(schematic, %{name: "NBA", sport: "basketball"})
  ```
  """
  @spec oneof([t() | lazy_schematic()] | (any -> t())) :: t()
  def oneof(schematics) when is_list(schematics) do
    message = fn -> "either #{sentence_join(schematics, "or", & &1.message.())}" end

    %Schematic{
      kind: "oneof",
      message: message,
      unify:
        telemetry_wrap(:oneof, %{style: :sequential}, fn input, dir ->
          inquiry =
            Enum.find_value(schematics, fn schematic ->
              schematic =
                case schematic do
                  {mod, func, args} -> apply(mod, func, args)
                  schematic -> schematic
                end

              with {:error, _} <- schematic.unify.(input, dir), do: false
            end)

          with nil <- inquiry, do: {:error, ~s|expected #{message.()}|}
        end)
    }
  end

  def oneof(dispatch) when is_function(dispatch) do
    %Schematic{
      kind: "oneof:dispatch",
      unify:
        telemetry_wrap(:oneof, %{style: :dispatch}, fn input, dir ->
          with %Schematic{} = schematic <- dispatch.(input) do
            schematic.unify.(input, dir)
          end
        end)
    }
  end

  defp sentence_join(items, joiner, mapper) do
    length = length(items)
    item_joiner = if length > 2, do: ", ", else: " "

    Enum.map_join(Enum.with_index(items), item_joiner, fn {item, idx} ->
      if idx == length - 1, do: joiner <> " " <> (mapper.(item) || ""), else: mapper.(item)
    end)
  end

  @doc """
  Unify external data with your internal data structures.

  See all the other functions for information on how to create schematics.
  """
  @spec unify(t(), any()) :: any()
  def unify(schematic, input) do
    schematic.unify.(input, :to)
  end

  @doc """
  Dump your internal data to their external data structures.

  See all the other functions for information on how to create schematics.
  """
  @spec dump(t(), any()) :: any()
  def dump(schematic, input) do
    schematic.unify.(input, :from)
  end

  defp telemetry_wrap(type, metadata, func) do
    fn input, dir ->
      metadata = Map.merge(%{kind: type, dir: dir}, metadata)

      :telemetry.span([:schematic, :unify], metadata, fn ->
        result = func.(input, dir)
        {result, metadata}
      end)
    end
  end

  @doc """
  See `map/1` for examples and explanation.
  """
  @spec optional(any) :: OptionalKey.t()
  def optional(key) do
    %OptionalKey{key: key}
  end
end
