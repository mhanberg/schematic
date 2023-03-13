defmodule MornTest do
  use ExUnit.Case

  import Morn

  defmodule Request do
    defstruct [:jsonrpc, :method, :params, :id]
  end

  describe "permeate" do
    test "str/0" do
      schematic = str()

      input = "lsp is kool"

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      assert {:error, "1 is not a string"} = permeate(schematic, 1)
    end

    test "str/1" do
      schematic = str("lsp is kool")

      input = "lsp is kool"

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      for i <- ["lsp is lame", 1, Map.new(), Keyword.new(), {nil}] do
        assert {:error, ~s|#{inspect(i)} != "lsp is kool"|} == permeate(schematic, i)
      end
    end

    test "int/0" do
      schematic = int()

      input = 999

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      assert {:error, ~s|"uh oh" is not an int|} = permeate(schematic, "uh oh")
    end

    test "int/1" do
      schematic = int(999)

      input = 999

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      for i <- ["lsp is lame", 1, Map.new(), Keyword.new(), {nil}] do
        assert {:error, ~s|#{inspect(i)} != 999|} == permeate(schematic, i)
      end
    end

    test "map/0" do
      schematic = map()

      input = %{}

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      assert {:error, ~s|"uh oh" is not a map|} = permeate(schematic, "uh oh")
    end

    test "list/0" do
      schematic = list()

      input = ["hello", "there"]

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = %{}

      assert {:error, ~s|%{} is not a list|} = permeate(schematic, input)
    end

    test "list/1" do
      schematic = list(int())

      input = [1, 2, 3]

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = ["hi", "there"]

      assert {:error, ~s|"hi" is not an int in ["hi", "there"]|} = permeate(schematic, input)
    end

    test "oneof/1" do
      schematic = oneof([int(), str()])

      input = 1
      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = "hi"
      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = []
      assert {:error, ~s|[] is not one of: integer, string|} = permeate(schematic, input)
    end

    test "map/1" do
      schematic =
        map(%{
          "foo" => str()
        })

      input = %{"foo" => "hi there!", "bar" => []}

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = %{"foo" => 1, "bar" => []}

      assert {:error, ~s|1 is not a string for key "foo" in %{"bar" => [], "foo" => 1}|} =
               permeate(schematic, input)
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

      assert {:ok, absorber} = permeate(schematic, input)
      assert input == absorber.()

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "three" => "the third"
            }
          }
        }
      }

      expected_error = ~s"""
      %{"three" => "the third"} is not one of: [map, map] for key "baz" in %{"baz" => %{"three" => "the third"}} for key "carol" in %{
        "alice" => "Alice",
        "bob" => ["is", "the", "coolest"],
        "carol" => %{"baz" => %{"three" => "the third"}}
      } for key "bar" in %{
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{"baz" => %{"three" => "the third"}}
        },
        "foo" => "hi there!"
      }
      """ |> String.trim()

      assert {:error, actual_error} = permeate(schematic, input)

      assert actual_error == expected_error
    end

    # test "works" do
    #   schematic =
    #     map(Request, %{
    #       {"jsonrpc", :jsonrpc} => str("2.0"),
    #       {"method", :method} => str("initialize"),
    #       {"params", :params} => map(%{}),
    #       {"id", :id} => int()
    #     })

    #   input = %{
    #     "jsonrpc" => "2.0",
    #     "method" => "initialize",
    #     "params" => %{},
    #     "id" => 1
    #   }

    #   assert {:ok, absorber} = permeate(schematic, input)

    #   assert %Request{
    #            jsonrpc: "2.0",
    #            method: "initialize",
    #            params: %{},
    #            id: 1
    #          } == absorber.()
    # end
  end
end
