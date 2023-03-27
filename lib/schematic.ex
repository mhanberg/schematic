defmodule Schematic do
  defstruct [:unify, :kind, :message]

  @opaque t :: %__MODULE__{
            unify: (term(), :up | :down -> {:ok, term()} | {:error, String.t() | [String.t()]}),
            kind: String.t(),
            message: String.t() | nil
          }

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
  end

  @spec any() :: t()
  def any() do
    %Schematic{kind: "any", unify: fn x, _dir -> {:ok, x} end}
  end

  @spec null() :: t()
  def null() do
    %Schematic{
      kind: "null",
      message: "null",
      unify: fn
        nil, _dir -> {:ok, nil}
        _input, _dir -> {:error, "expected null"}
      end
    }
  end

  @spec nullable(t()) :: t()
  def nullable(schematic) do
    oneof([null(), schematic])
  end

  @spec bool(boolean() | nil) :: t()
  def bool(literal \\ nil) do
    message =
      if is_boolean(literal) do
        "#{inspect(literal)}"
      else
        "a boolean"
      end

    %Schematic{
      kind: "boolean",
      message: message,
      unify: fn input, _dir ->
        # FIXME: this is ugly
        cond do
          is_boolean(literal) ->
            if is_boolean(input) && input == literal do
              {:ok, input}
            else
              {:error, ~s|expected #{message}|}
            end

          is_boolean(input) ->
            {:ok, input}

          true ->
            {:error, "expected #{message}"}
        end
      end
    }
  end

  @spec str(String.t() | nil) :: t()
  def str(literal \\ nil) do
    message =
      if literal do
        "the literal string #{inspect(literal)}"
      else
        "a string"
      end

    %Schematic{
      kind: "string",
      message: message,
      unify: fn input, _dir ->
        # FIXME: this is ugly
        cond do
          is_binary(literal) ->
            if is_binary(input) && input == literal do
              {:ok, input}
            else
              {:error, ~s|expected #{message}|}
            end

          is_binary(input) ->
            {:ok, input}

          true ->
            {:error, "expected #{message}"}
        end
      end
    }
  end

  @spec int(integer() | nil) :: t()
  def int(literal \\ nil) do
    message =
      if literal do
        "the literal integer #{inspect(literal)}"
      else
        "an integer"
      end

    %Schematic{
      kind: "integer",
      message: message,
      unify: fn input, _dir ->
        # FIXME: this is ugly
        cond do
          is_integer(literal) ->
            if is_integer(input) && input == literal do
              {:ok, input}
            else
              {:error, ~s|expected #{message}|}
            end

          is_integer(input) ->
            {:ok, input}

          true ->
            {:error, "expected #{message}"}
        end
      end
    }
  end

  @spec list() :: t()
  def list() do
    message = "a list"

    %Schematic{
      kind: "list",
      message: message,
      unify: fn input, _dir ->
        if is_list(input) do
          {:ok, input}
        else
          {:error, ~s|expected #{message}|}
        end
      end
    }
  end

  @spec list(t()) :: t()
  def list(schematic) do
    message = "a list of #{schematic.message}"

    %Schematic{
      kind: "list",
      message: message,
      unify: fn input, dir ->
        if is_list(input) do
          Enum.reduce_while(input, {:ok, []}, fn el, {:ok, acc} ->
            case schematic.unify.(el, dir) do
              {:ok, output} ->
                {:cont, {:ok, [output | acc]}}

              {:error, _error} ->
                {:halt, {:error, ~s|expected #{message}|}}
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
      end
    }
  end

  @spec tuple([t()], Keyword.t()) :: t()
  def tuple(schematics, opts \\ []) do
    message = "a tuple of [#{Enum.map_join(schematics, ", ", & &1.message)}]"
    from = Keyword.get(opts, :from, :tuple)

    {condition, to_list} =
      case from do
        :list ->
          {&is_list/1, &Function.identity/1}

        :tuple ->
          {&is_tuple/1, &Tuple.to_list/1}
      end

    %Schematic{
      kind: "tuple",
      message: message,
      unify: fn input, dir ->
        if condition.(input) do
          input
          |> to_list.()
          |> Enum.with_index()
          |> Enum.reduce_while({:ok, []}, fn {el, idx}, {:ok, acc} ->
            case Enum.at(schematics, idx).unify.(el, dir) do
              {:ok, output} ->
                {:cont, {:ok, [output | acc]}}

              {:error, _error} ->
                {:halt, {:error, ~s|expected #{message}|}}
            end
          end)
          |> then(fn
            {:ok, result} ->
              {:ok, result |> Enum.reverse() |> List.to_tuple()}

            error ->
              error
          end)
        else
          {:error, ~s|expected a list|}
        end
      end
    }
  end

  @spec map(map() | Keyword.t()) :: t()
  def map(blueprint \\ %{})

  def map(blueprint) when is_map(blueprint) do
    %Schematic{
      kind: "map",
      message: "a map",
      unify: fn input, dir ->
        if is_map(input) do
          bp_keys = Map.keys(blueprint)

          Enum.reduce(
            bp_keys,
            [ok: %{}, errors: %{}],
            fn bpk, [{:ok, acc}, {:errors, errors}] ->
              schematic = blueprint[bpk]
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
                      |> Map.delete(from_key)
                      |> Map.put(to_key, output)

                    [{:ok, acc}, {:errors, errors}]

                  {:error, error} ->
                    [{:ok, acc}, {:errors, Map.put(errors, from_key, error)}]
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
      end
    }
  end

  def map(opts) when is_list(opts) do
    key_schematic = Keyword.get(opts, :keys, any())
    value_schematic = Keyword.get(opts, :values, any())

    %Schematic{
      kind: "map",
      message: "a map",
      unify: fn input, dir ->
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
      end
    }
  end

  @spec schema(atom(), map()) :: t()
  def schema(mod, schematic) do
    schematic =
      map(
        Map.new(schematic, fn
          {k, v} when is_atom(k) ->
            {{to_string(k), k}, v}

          kv ->
            kv
        end)
      )

    %Schematic{
      kind: "map",
      message: "a %#{String.replace(to_string(mod), "Elixir.", "")}{}",
      unify: fn input, dir ->
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
      end
    }
  end

  defp struct?(%struct{} = input, mod) when struct == mod do
    {:ok, input}
  end

  defp struct?(_input, mod) do
    {:error, "expected a #{mod} struct"}
  end

  @spec raw((any() -> boolean()), [tuple()]) :: t()
  def raw(function, opts \\ []) do
    message = Keyword.get(opts, :message, "is invalid")
    transformer = Keyword.get(opts, :transform, fn input, _dir -> input end)

    %Schematic{
      kind: "function",
      message: message,
      unify: fn input, dir ->
        if convert_to_two_arity(function).(input, dir) do
          {:ok, convert_to_two_arity(transformer).(input, dir)}
        else
          {:error, message}
        end
      end
    }
  end

  defp convert_to_two_arity(f) when is_function(f, 1) do
    fn a, _ -> f.(a) end
  end

  defp convert_to_two_arity(f) when is_function(f, 2) do
    f
  end

  @spec all([t()]) :: t()
  def all(schematics) when is_list(schematics) do
    message = Enum.map(schematics, & &1.message)

    %Schematic{
      kind: "all",
      message: message,
      unify: fn input, dir ->
        errors =
          for schematic <- schematics,
              {result, message} = schematic.unify.(input, dir),
              result == :error do
            message
          end

        if Enum.empty?(errors) do
          {:ok, input}
        else
          {:error, errors}
        end
      end
    }
  end

  @spec oneof([t()] | (any -> t())) :: t()
  def oneof(schematics) when is_list(schematics) do
    message = "either #{sentence_join(schematics, "or", & &1.message)}"

    %Schematic{
      kind: "oneof",
      message: message,
      unify: fn input, dir ->
        inquiry =
          Enum.find_value(schematics, fn schematic ->
            with {:error, _} <- schematic.unify.(input, dir), do: false
          end)

        with nil <- inquiry, do: {:error, ~s|expected #{message}|}
      end
    }
  end

  def oneof(dispatch) when is_function(dispatch) do
    %Schematic{
      kind: "oneof",
      unify: fn input, dir ->
        with %Schematic{} = schematic <- dispatch.(input) do
          schematic.unify.(input, dir)
        end
      end
    }
  end

  defp sentence_join(items, joiner, mapper) do
    length = length(items)
    item_joiner = if length > 2, do: ", ", else: " "

    Enum.map_join(Enum.with_index(items), item_joiner, fn {item, idx} ->
      if idx == length - 1, do: joiner <> " " <> (mapper.(item) || ""), else: mapper.(item)
    end)
  end

  @spec unify(t(), any()) :: any()
  def unify(schematic, input) do
    schematic.unify.(input, :to)
  end

  @spec dump(t(), any()) :: any()
  def dump(schematic, input) do
    schematic.unify.(input, :from)
  end

  @spec optional(any) :: %OptionalKey{key: any()}
  def optional(key) do
    %OptionalKey{key: key}
  end
end
