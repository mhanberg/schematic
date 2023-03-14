# 📐 schematic

mitch's scrambled take on norm

## Example

```elixir
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

assimilate(schematic, input)

# returns...

{:ok,
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
  }}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `schematic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:schematic, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/schematic>.
