# 📐 schematic

schematic is a library for data validation and transformation.

## Example

```elixir
import Schematic

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

```elixir
def deps do
  [
    {:schematic, "~> 0.0.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/schematic>.

## License

The MIT License (MIT)

Copyright © 2023 Mitchell A. Hanberg

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
