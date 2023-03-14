defmodule MornTest do
  use ExUnit.Case, async: true

  import Morn

  defmodule Request do
    defstruct [:jsonrpc, :method, :params, :id]
  end

  describe "permeate" do
    test "str/0" do
      schematic = str()
      input = "lsp is kool"
      assert {:ok, input} == permeate(schematic, input)
    end

    test "str/1" do
      schematic = str("lsp is kool")
      input = "lsp is kool"
      assert {:ok, input} == permeate(schematic, input)
    end

    test "int/0" do
      schematic = int()
      input = 999
      assert {:ok, input} == permeate(schematic, input)
    end

    test "int/1" do
      schematic = int(999)
      input = 999
      assert {:ok, input} == permeate(schematic, input)
    end

    test "map/0" do
      schematic = map()
      input = %{}
      assert {:ok, input} == permeate(schematic, input)
    end

    test "list/0" do
      schematic = list()
      input = ["hello", "there"]
      assert {:ok, input} == permeate(schematic, input)
    end

    test "list/1" do
      schematic = list(int())
      input = [1, 2, 3]
      assert {:ok, input} == permeate(schematic, input)
    end

    test "oneof/1" do
      schematic = oneof([int(), str()])
      input = 1
      assert {:ok, input} == permeate(schematic, input)

      input = "hi"
      assert {:ok, input} == permeate(schematic, input)
    end

    test "map/1" do
      schematic =
        map(%{
          "foo" => str()
        })

      input = %{"foo" => "hi there!", "bar" => []}
      assert {:ok, input} == permeate(schematic, input)
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

      assert {:ok, input} == permeate(schematic, input)
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
              }} == permeate(schematic, input)
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
              }} == permeate(schematic, input)
    end
  end

  describe "error messages" do
    test "validates every key of a map" do
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
              "second" => list(oneof([list(), map()]))
            })
        })

      input = %{
        "foo" => %{},
        "bar" => 1,
        "baz" => "hi!",
        "alice" => "bob",
        "dave" => %{
          "first" => "name",
          "second" => ["hi", "there"]
        }
      }

      assert {:error,
              %{
                "foo" => "expected a string, integer, or list",
                "bar" => "expected a string",
                "baz" => "expected a list",
                "alice" => ~s|expected the string "foo"|,
                "bob" => ~s|expected the integer 99|,
                "dave" => %{
                  "first" => "expected an integer",
                  "second" => "idk",
                }
              }} == permeate(schematic, input)
    end
  end
end
