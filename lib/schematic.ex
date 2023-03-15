defmodule Schematic do
  defstruct [:assimilate, :kind, :message]

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

  def map(blueprint \\ %{}) do
    %Schematic{
      kind: "map",
      message: "a map",
      assimilate: fn input ->
        if is_map(input) do
          bp_keys = Map.keys(blueprint)

          Enum.reduce(
            bp_keys,
            [ok: input, errors: %{}],
            fn bpk, [{:ok, acc}, {:errors, errors}] ->
              schematic = blueprint[bpk]
              {from_key, to_key} = with key when not is_tuple(key) <- bpk, do: {key, key}

              if schematic do
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
              else
                [{:ok, acc}, {:errors, Map.put(errors, from_key, "is blank")}]
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

  def oneof(schematics) do
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
end
