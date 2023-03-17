defmodule Schematic do
  defstruct [:assimilate, :kind, :message]

  defmodule OptionalKey do
    @enforce_keys [:key]
    defstruct [:key]
  end

  def any() do
    %Schematic{kind: :any, message: "", assimilate: fn x -> {:ok, x} end}
  end

  def null() do
    %Schematic{
      kind: :null,
      message: "null",
      assimilate: fn
        nil -> {:ok, nil}
        _input -> {:error, "expected null"}
      end
    }
  end

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
      assimilate: fn input ->
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
      assimilate: fn input ->
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
      assimilate: fn input ->
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

  def list() do
    message = "a list"

    %Schematic{
      kind: "list",
      message: message,
      assimilate: fn input ->
        if is_list(input) do
          {:ok, input}
        else
          {:error, ~s|expected #{message}|}
        end
      end
    }
  end

  def list(schematic) do
    message = "a list of #{schematic.message}"

    %Schematic{
      kind: "list",
      message: message,
      assimilate: fn input ->
        if is_list(input) do
          Enum.reduce_while(input, {:ok, []}, fn el, {:ok, acc} ->
            case assimilate(schematic, el) do
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
      assimilate: fn input ->
        if condition.(input) do
          input
          |> to_list.()
          |> Enum.with_index()
          |> Enum.reduce_while({:ok, []}, fn {el, idx}, {:ok, acc} ->
            case(assimilate(Enum.at(schematics, idx), el)) do
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

  def map(blueprint \\ %{})

  def map(blueprint) when is_map(blueprint) do
    %Schematic{
      kind: "map",
      message: "a map",
      assimilate: fn input ->
        if is_map(input) do
          bp_keys = Map.keys(blueprint)

          Enum.reduce(
            bp_keys,
            [ok: %{}, errors: %{}],
            fn bpk, [{:ok, acc}, {:errors, errors}] ->
              schematic = blueprint[bpk]
              key = with %OptionalKey{key: key} <- bpk, do: key
              {from_key, to_key} = with key when not is_tuple(key) <- key, do: {key, key}

              if not Map.has_key?(input, from_key) and match?(%OptionalKey{}, bpk) do
                [{:ok, acc}, {:errors, errors}]
              else
                case assimilate(schematic, input[from_key]) do
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
    key_schematic = Keyword.get(opts, :keys, func(&Function.identity/1, message: ""))
    value_schematic = Keyword.get(opts, :values, func(&Function.identity/1, message: ""))

    %Schematic{
      kind: "map",
      message: "a map",
      assimilate: fn input ->
        if is_map(input) do
          Enum.reduce(
            Map.keys(input),
            [ok: %{}, errors: %{}],
            fn input_key, [{:ok, acc}, {:errors, errors}] ->
              case assimilate(key_schematic, input_key) do
                {:ok, key_output} ->
                  case assimilate(value_schematic, input[input_key]) do
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

  def schema(mod, schematic) do
    schematic =
      Map.new(schematic, fn
        {k, v} when is_atom(k) ->
          {{to_string(k), k}, v}

        kv ->
          kv
      end)

    %Schematic{
      kind: "map",
      message: "a map",
      assimilate: fn input ->
        with {:ok, output} <- assimilate(map(schematic), input) do
          {:ok, struct(mod, output)}
        end
      end
    }
  end

  def func(function, opts \\ []) do
    message = Keyword.get(opts, :message, "is invalid")
    transformer = Keyword.get(opts, :transform, &Function.identity/1)

    %Schematic{
      kind: "function",
      message: message,
      assimilate: fn input ->
        if function.(input) do
          {:ok, transformer.(input)}
        else
          {:error, message}
        end
      end
    }
  end

  def all(schematics) when is_list(schematics) do
    message = Enum.map(schematics, & &1.message)

    %Schematic{
      kind: "all",
      message: message,
      assimilate: fn input ->
        errors =
          for schematic <- schematics,
              {result, message} = assimilate(schematic, input),
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

  def oneof(schematics) when is_list(schematics) do
    message = "either #{sentence_join(schematics, "or", & &1.message)}"

    %Schematic{
      kind: "oneof",
      message: message,
      assimilate: fn input ->
        inquiry =
          Enum.find_value(schematics, fn schematic ->
            with {:error, _} <- assimilate(schematic, input) do
              false
            end
          end)

        with nil <- inquiry do
          {:error, ~s|expected #{message}|}
        end
      end
    }
  end

  defp sentence_join(items, joiner, mapper) do
    length = length(items)
    item_joiner = if length > 2, do: ", ", else: " "

    Enum.map_join(Enum.with_index(items), item_joiner, fn {item, idx} ->
      if idx == length - 1, do: joiner <> " " <> mapper.(item), else: mapper.(item)
    end)
  end

  def assimilate(schematic, input) do
    schematic.assimilate.(input)
  end

  def optional(key) do
    %OptionalKey{key: key}
  end
end
