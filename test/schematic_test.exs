defmodule SchematicTest do
  use ExUnit.Case, async: true

  import ExUnitProperties, only: :macros
  import Schematic

  alias SchematicTest.Generators

  defmodule Request do
    defstruct [:jsonrpc, :method, :params, :id]
  end

  defmodule HTTPRequest do
    defstruct [:method, :body]
  end

  unless Version.match?(System.version(), "~> 1.11.0 or ~> 1.10.0") do
    doctest Schematic, tags: [doctest: true]
  end

  describe "unify" do
    property "input |> unify |> dump == input" do
      check all {schematic, input} <- Generators.schematic_and_data() do
        assert {:ok, input} ==
                 unify(schematic, input) |> then(fn {:ok, result} -> dump(schematic, result) end)
      end
    end

    test "any/0" do
      assert {:ok, "hi"} == unify(any(), "hi")
    end

    test "str/0" do
      schematic = str()
      input = "lsp is kool"
      assert {:ok, input} == unify(schematic, input)
    end

    test "str/1" do
      schematic = str("lsp is kool")
      input = "lsp is kool"
      assert {:ok, input} == unify(schematic, input)
    end

    test "int/0" do
      schematic = int()
      input = 999
      assert {:ok, input} == unify(schematic, input)
    end

    test "int/1" do
      schematic = int(999)
      input = 999
      assert {:ok, input} == unify(schematic, input)
    end

    test "map/0" do
      schematic = map()
      input = %{}
      assert {:ok, input} == unify(schematic, input)
    end

    test "list/0" do
      schematic = list()
      input = ["hello", "there"]
      assert {:ok, input} == unify(schematic, input)
    end

    test "list/1" do
      schematic = list(int())
      input = [1, 2, 3]
      assert {:ok, input} == unify(schematic, input)
    end

    test "tuple/2" do
      schematic = tuple([int(), str(), map(%{alice: any()})])

      input = {1, "2", %{alice: :bob}}
      assert {:ok, {1, "2", %{alice: :bob}}} == unify(schematic, input)

      input = {"1", 3, []}

      assert {:error, "expected a tuple of {an integer, a string, a map}"} ==
               unify(schematic, input)

      input = {1, "2", %{alice: :bob}, []}

      assert {:error, "expected a tuple of {an integer, a string, a map}"} ==
               unify(schematic, input)
    end

    test "tuple/2 from list" do
      schematic = tuple([int(), str(), map(%{alice: any()})], from: :list)

      input = [1, "2", %{alice: :bob}]
      assert {:ok, {1, "2", %{alice: :bob}}} == unify(schematic, input)

      input = ["1", 3, []]

      assert {:error, "expected a list of {an integer, a string, a map}"} ==
               unify(schematic, input)

      input = [1, "2", %{alice: :bob}, []]

      assert {:error, "expected a list of {an integer, a string, a map}"} ==
               unify(schematic, input)
    end

    test "oneof/1" do
      schematic = oneof([int(), str()])
      input = 1
      assert {:ok, input} == unify(schematic, input)

      input = "hi"
      assert {:ok, input} == unify(schematic, input)
    end

    test "map/1" do
      schematic =
        map(%{
          "foo" => str()
        })

      input = %{"foo" => "hi there!", "bar" => []}
      assert {:ok, %{"foo" => "hi there!"}} == unify(schematic, input)
    end

    property "map/1 with nullable values" do
      check all [data_schematic, alternative_data_schematic] <-
                  Generators.simple_schematic(excluding: ["null"])
                  |> StreamData.uniq_list_of(length: 2),
                non_null_input <-
                  Generators.from_simple_schematic(data_schematic)
                  |> StreamData.bind(&StreamData.constant(%{data: &1})),
                alternative_input <-
                  Generators.from_simple_schematic(alternative_data_schematic)
                  |> StreamData.bind(&StreamData.constant(%{data: &1})) do
        schematic = map(%{data: nullable(data_schematic)})

        assert {:ok, non_null_input} == unify(schematic, non_null_input)
        assert {:ok, %{data: nil}} == unify(schematic, %{type: nil})
        assert {:ok, %{data: nil}} == unify(schematic, %{alt: alternative_input})
      end
    end

    property "map/1 with optional keys" do
      check all [optional_schematic, data_schematic] <-
                  Generators.simple_schematic()
                  |> StreamData.list_of(length: 2),
                optional_value <- Generators.from_simple_schematic(optional_schematic),
                data_value <- Generators.from_simple_schematic(data_schematic) do
        schematic =
          map(%{
            optional(:optional) => optional_schematic,
            data: data_schematic
          })

        assert {:ok, %{data: data_value}} == unify(schematic, %{data: data_value})

        assert {:ok, %{data: data_value, optional: optional_value}} ==
                 unify(schematic, %{data: data_value, optional: optional_value})
      end
    end

    test "complex" do
      schematic =
        map(%{
          "foo" => oneof([str(), int()]),
          "bar" =>
            map(%{
              "alice" => str("Alice"),
              "bob" => list(str()),
              "carol" =>
                map(%{
                  "baz" =>
                    oneof([
                      map(%{"one" => int()}),
                      map(%{"two" => str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok, input} == unify(schematic, input)
    end

    test "complex transformer" do
      schematic =
        map(%{
          {"foo", :foo} => oneof([str(), int()]),
          {"bar", :bar} =>
            map(%{
              {"alice", :alice} => str("Alice"),
              {"bob", :bob} => list(str()),
              {"carol", :carol} =>
                map(%{
                  {"baz", :baz} =>
                    oneof([
                      map(%{{"one", :one} => int()}),
                      map(%{{"two", :two} => str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok,
              %{
                foo: "hi there!",
                bar: %{
                  alice: "Alice",
                  bob: ["is", "the", "coolest"],
                  carol: %{
                    baz: %{
                      two: "the second"
                    }
                  }
                }
              }} == unify(schematic, input)
    end

    defmodule S1 do
      defstruct [:foo, :bar]
    end

    defmodule S2 do
      defstruct [:alice, :bob, :carol]
    end

    defmodule S3 do
      defstruct [:baz]
    end

    defmodule S4 do
      defstruct [:one]
    end

    defmodule S5 do
      defstruct [:two]
    end

    test "complex transformer with structs" do
      schematic =
        schema(S1, %{
          {"foo", :foo} => oneof([str(), int()]),
          bar:
            schema(S2, %{
              {"alice", :alice} => str("Alice"),
              {"bob", :bob} => list(str()),
              {"carol", :carol} =>
                schema(S3, %{
                  {"baz", :baz} =>
                    oneof([
                      schema(S4, %{one: int()}),
                      schema(S5, %{two: str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok,
              %S1{
                foo: "hi there!",
                bar: %S2{
                  alice: "Alice",
                  bob: ["is", "the", "coolest"],
                  carol: %S3{
                    baz: %S5{
                      two: "the second"
                    }
                  }
                }
              }} == unify(schematic, input)
    end

    test "bool/1" do
      schematic = bool()

      assert {:ok, true} = unify(schematic, true)
      assert {:ok, false} = unify(schematic, false)

      schematic = bool(true)
      assert {:ok, true} = unify(schematic, true)
      assert {:error, "expected true"} = unify(schematic, false)

      schematic = bool(false)
      assert {:ok, false} = unify(schematic, false)
      assert {:error, "expected false"} = unify(schematic, true)
    end

    test "raw/2" do
      schematic = raw(fn n, _ -> n > 10 end, message: "must be greater than 10")

      assert {:ok, 12} = unify(schematic, 12)
      assert {:error, "must be greater than 10"} = unify(schematic, 9)
    end

    test "raw/2 with :transform option" do
      schematic =
        raw(
          fn
            n, :to -> is_list(n) and length(n) == 3
            n, :from -> is_tuple(n) and tuple_size(n) == 3
          end,
          message: "must be a tuple of size 3",
          transform: fn
            input, :to ->
              List.to_tuple(input)

            input, :from ->
              Tuple.to_list(input)
          end
        )

      assert {:ok, {"one", "two", 3}} = unify(schematic, ["one", "two", 3])
      assert {:error, "must be a tuple of size 3"} = unify(schematic, ["not", "big"])
      assert {:ok, ["one", "two", 3]} = dump(schematic, {"one", "two", 3})
    end

    test "all/1" do
      schematic =
        all([
          int(),
          raw(fn i, _ -> i > 10 end, message: "must be greater than 10"),
          raw(fn i, _ -> i < 20 end, message: "must be less than 20")
        ])

      assert {:ok, 12} = unify(schematic, 12)
      assert {:error, ["must be greater than 10"]} = unify(schematic, 9)
      assert {:error, ["must be less than 20"]} = unify(schematic, 21)

      assert {:error, ["expected an integer", "must be less than 20"]} = unify(schematic, "hi")
    end
  end

  describe "error messages" do
    test "validates every key of a map" do
      teacher =
        map(%{
          "name" => str(),
          "grade" => int(),
          "prefix" => oneof([str("Mrs."), str("Mr.")])
        })

      schematic =
        map(%{
          "foo" => oneof([str(), int(), list()]),
          "bar" => str(),
          "baz" => list(),
          "alice" => str("foo"),
          "bob" => int(99),
          "carol" => oneof([null(), int()]),
          "dave" =>
            map(%{
              "first" => int(),
              "second" => list(oneof([list(), map()])),
              "teacher" => teacher
            })
        })

      input = %{
        "foo" => %{},
        "bar" => 1,
        "baz" => "hi!",
        "alice" => "bob",
        "dave" => %{
          "first" => "name",
          "second" => ["hi", "there"],
          "teacher" => %{}
        }
      }

      assert {:error,
              %{
                "alice" => "expected the literal string \"foo\"",
                "bar" => "expected a string",
                "baz" => "expected a list",
                "bob" => "expected the literal integer 99",
                "dave" => %{
                  "first" => "expected an integer",
                  "second" => "expected a list of either a list or a map",
                  "teacher" => %{
                    "grade" => "expected an integer",
                    "name" => "expected a string",
                    "prefix" =>
                      "expected either the literal string \"Mrs.\" or the literal string \"Mr.\""
                  }
                },
                "foo" => "expected either a string, an integer, or a list"
              }} == unify(schematic, input)
    end

    test "nullable values" do
      schematic =
        map(%{
          type: oneof([null(), int()])
        })

      assert {:ok, %{type: 10}} == unify(schematic, %{type: 10})
      assert {:ok, %{type: nil}} == unify(schematic, %{type: nil})
      assert {:ok, %{type: nil}} == unify(schematic, %{name: "bob"})
    end

    test "optional keys" do
      schematic =
        map(%{
          optional(:name) => str(),
          type: int()
        })

      assert {:ok, %{type: 10}} == unify(schematic, %{type: 10})
      assert {:ok, %{type: 10, name: "bob"}} == unify(schematic, %{type: 10, name: "bob"})

      assert {:error, %{name: "expected a string"}} ==
               unify(schematic, %{type: 10, name: 10})
    end

    test "empty map" do
      schematic = map()

      assert {:ok, %{"foo" => 1}} == unify(schematic, %{"foo" => 1})
    end

    test "key types" do
      schematic = map(keys: str(), values: str())

      assert {:ok, %{"foo" => "one"}} == unify(schematic, %{"foo" => "one", 1 => "bam"})

      assert {:error, %{"foo" => "expected a string"}} ==
               unify(schematic, %{"foo" => 1, 1 => "bam"})

      schematic =
        map(
          keys: all([int(), raw(fn n -> n > 5 end, message: "greater than 5")]),
          values: str()
        )

      assert {:ok, %{6 => "6"}} == unify(schematic, %{6 => "6", 1 => "bam"})

      schematic =
        map(
          keys:
            raw(fn n ->
              case n do
                n when is_binary(n) -> match?({_, ""}, Integer.parse(n))
                _ -> false
              end
            end),
          values: str()
        )

      assert {:ok, %{"6" => "has a string key that parses as an integer"}} ==
               unify(schematic, %{
                 "6" => "has a string key that parses as an integer",
                 1 => "bam"
               })

      schematic =
        map(
          keys:
            raw(fn n -> is_binary(n) and match?({_, ""}, Integer.parse(n)) end,
              transform: &String.to_integer/1
            ),
          values: str()
        )

      assert {:ok, %{6 => "has a string key that parses as an integer"}} ==
               unify(schematic, %{
                 "6" => "has a string key that parses as an integer",
                 1 => "bam"
               })
    end
  end

  describe "dump" do
    test "dumps map with key conversions" do
      schematic =
        map(%{
          {"camelCase", :snake_case} => str(),
          optional({"camelCase2", :snake_case2}) => str(),
          {"camelCase3", :snake_case3} => oneof([null(), str()])
        })

      assert {:ok, %{snake_case: "foo!"}} = unify(schematic, %{"camelCase" => "foo!"})

      assert {:ok, %{"camelCase" => "foo!", "camelCase3" => nil}} ==
               dump(schematic, %{snake_case: "foo!"})

      assert {:ok, %{"camelCase" => "foo!", "camelCase2" => "bar", "camelCase3" => nil}} ==
               dump(schematic, %{snake_case: "foo!", snake_case2: "bar"})
    end

    property "dumps map with key conversions" do
      check all from_keys <- StreamData.uniq_list_of(StreamData.binary(), min_length: 2),
                to_keys <-
                  StreamData.uniq_list_of(StreamData.binary(), length: Enum.count(from_keys)),
                schematics <-
                  StreamData.list_of(Generators.simple_schematic(), length: Enum.count(from_keys)),
                values <-
                  StreamData.bind(StreamData.constant(schematics), fn schems ->
                    StreamData.fixed_list(Enum.map(schems, &Generators.from_simple_schematic/1))
                  end) do
        schematic =
          Enum.zip([from_keys, to_keys, schematics])
          |> Enum.map(fn {from, to, schem} -> {{from, to}, schem} end)
          |> Map.new()
          |> map()

        input =
          Enum.zip(from_keys, values)
          |> Map.new()

        expected_unify_result =
          Enum.zip(to_keys, values)
          |> Map.new()

        assert {:ok, expected_unify_result} == unify(schematic, input)
        assert {:ok, input} == dump(schematic, expected_unify_result)
      end
    end

    test "works with schema" do
      schematic = schema(SchematicTest.S3, %{baz: schema(SchematicTest.S4, %{one: str()})})

      assert {:ok, %SchematicTest.S3{baz: %SchematicTest.S4{one: "yo"}}} ==
               unify(schematic, %{"baz" => %{"one" => "yo"}})

      assert {:ok, %{"baz" => %{"one" => "yo"}}} ==
               dump(schematic, %SchematicTest.S3{baz: %SchematicTest.S4{one: "yo"}})
    end

    test "works with oneof" do
      schematic =
        map(%{
          {"oneTwo", :one_two} =>
            oneof([
              map(%{{"threeFour", :three_four} => str()}),
              map(%{{"fiveSix", :five_six} => int()})
            ])
        })

      assert {:ok, %{one_two: %{five_six: 1}}} ==
               unify(schematic, %{"oneTwo" => %{"fiveSix" => 1}})

      assert {:ok, %{"oneTwo" => %{"fiveSix" => 1}}} ==
               dump(schematic, %{one_two: %{five_six: 1}})
    end

    test "works with lists" do
      schematic = list(map(%{{"camelCase", :snake_case} => str()}))

      assert {:ok, [%{snake_case: "foo!"}]} = unify(schematic, [%{"camelCase" => "foo!"}])
      assert {:ok, [%{"camelCase" => "foo!"}]} == dump(schematic, [%{snake_case: "foo!"}])
    end
  end

  describe "dispatch" do
    test "oneof can dispatch to a specific schematic with a closure" do
      schematic =
        oneof(fn
          %{type: "foo"} ->
            map(%{type: str("foo")})

          %{type: "bar"} ->
            map(%{type: str("bar")})

          %{type: "baz"} ->
            map(%{type: str("baz")})

          %{type: type} ->
            {:error, ~s|unexpected record type "#{type}"|}

          _ ->
            map(%{type: str()})
        end)

      assert {:ok, %{type: "bar"}} == unify(schematic, %{type: "bar"})
      assert {:error, %{type: "expected a string"}} == unify(schematic, %{typo: "doink"})
      assert {:error, ~s|unexpected record type "doink"|} == unify(schematic, %{type: "doink"})
    end
  end

  defmodule OptionalSchema do
    defstruct [:required, :optional]
  end

  describe "optional keys on schemas" do
    test "will omit optional key when dumping" do
      schematic =
        schema(SchematicTest.OptionalSchema, %{
          optional(:optional) => str(),
          required: str()
        })

      assert {:ok, %SchematicTest.OptionalSchema{required: "foo!"}} ==
               unify(schematic, %{"required" => "foo!"})

      assert {:ok, %{"required" => "foo!"}} ==
               dump(schematic, %SchematicTest.OptionalSchema{required: "foo!"})
    end
  end

  defmodule Recursive do
    import Schematic

    def foo() do
      map(%{
        optional(:recursive) => {__MODULE__, :foo, []},
        optional(:recursive_list) => list({__MODULE__, :foo, []}),
        foo: str(),
        bar: int()
      })
    end
  end

  describe "recursive schematics" do
    setup do
      [schematic: Recursive.foo()]
    end

    test "doesn't infinitely loop", %{schematic: schematic} do
      assert {:ok,
              %{
                foo: "hi",
                bar: 99,
                recursive_list: [%{foo: "bye", bar: 0, recursive: %{foo: "yo", bar: 420}}],
                recursive: %{foo: "bye", bar: 0, recursive: %{foo: "yo", bar: 420}}
              }} =
               unify(schematic, %{
                 foo: "hi",
                 bar: 99,
                 recursive_list: [%{foo: "bye", bar: 0, recursive: %{foo: "yo", bar: 420}}],
                 recursive: %{foo: "bye", bar: 0, recursive: %{foo: "yo", bar: 420}}
               })
    end

    test "correctly unifies", %{schematic: schematic} do
      assert {:error,
              %{
                recursive: %{recursive: "expected a map"},
                recursive_list: "expected a list of a map"
              }} ==
               unify(schematic, %{
                 foo: "hi",
                 bar: 99,
                 recursive_list: ["this shouldn't work"],
                 recursive: %{foo: "bye", bar: 0, recursive: "this shouldn't work"}
               })
    end
  end
end
