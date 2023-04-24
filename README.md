# schematic

[![Hex.pm](https://img.shields.io/hexpm/v/schematic)](https://hex.pm/packages/schematic)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/schematic/)

<img width="300px" src="https://user-images.githubusercontent.com/5523984/229656560-e1e96c2c-b51f-481a-b8e3-00127432b20e.png" alt="schematic logo">

<!-- MDOC !-->

schematic is a library for data specification, validation, and transformation.

schematic works by constructing **schematics** that specify your data and can then **unify** to them from external data and **dump** your internal data back to the external data.

There are 12 builtin schematics that you can use to build new schematics that fit your own domain model.

- `null/0`
- `bool/1`
- `str/1`
- `int/1`
- `list/1`
- `tuple/1`
- `map/1`
- `schema/2`
- `raw/2`
- `any/0`
- `all/1`
- `oneof/1`

## Example

Let's take a look at an example schematic for a JSON-RPC request for a bookstore API.

```elixir
defmodule Bookstore do
  defmodule Datetime do
    import Schematic

    def schematic() do
      raw(
        fn
          i, :to -> is_binary(i) and match?({:ok, _, _}, DateTime.from_iso8601(i))
          i, :from -> match?(%DateTime{}, i)
        end,
        transform: fn
          i, :to ->
            {:ok, dt, _} = DateTime.from_iso8601(i)
            dt

          i, :from ->
            DateTime.to_iso8601(i)
        end
      )
    end
  end

  defmodule Enum do
    import Schematic

    def schematic(strings) do
      oneof(Elixir.Enum.map(strings, &str/1))
    end
  end

  defmodule Author do
    import Schematic

    defstruct [:name]

    def schematic() do
      schema(__MODULE__, %{
        name: str()
      })
    end
  end

  defmodule Book do
    import Schematic

    defstruct [:title, :authors, :publication_date]

    def schematic() do
      schema(__MODULE__, %{
        {"publicationDate", :publication_date} => Bookstore.Datetime.schematic(),
        title: str(),
        authors: list(Bookstore.Author.schematic())
      })
    end
  end

  defmodule BooksListResult do
    import Schematic

    defstruct [:books]

    def schematic() do
      schema(__MODULE__, %{
        books: list(Bookstore.Book.schematic())
      })
    end
  end

  defmodule BooksListParams do
    import Schematic

    defstruct [:query, :order]

    def schematic() do
      schema(__MODULE__, %{
        query:
          nullable(
            map(%{
              {"field", :field} =>
                SchematicTest.Bookstore.Enum.schematic(["title", "authors", "publication_date"]),
              {"value", :value} => str()
            })
          ),
        order: nullable(oneof([str("asc"), str("desc")]))
      })
    end
  end

  defmodule BooksList do
    import Schematic

    defstruct [:id, :method, :params]

    def schematic() do
      schema(__MODULE__, %{
        id: int(),
        method: str("books/list"),
        params: Bookstore.BooksListParams.schematic()
      })
    end
  end
end
```

Reading external data into your data model.

```elixir
iex> alias SchematicTest.Bookstore
iex> import Schematic
iex> unify(Bookstore.BooksList.schematic(), %{
...>   "id" => 99,
...>   "method" => "books/list",
...>   "params" => %{
...>     "query" => %{
...>       "field" => "authors",
...>       "value" => "Michael Crichton"
...>     },
...>     "order" => "desc"
...>   }
...> })
{:ok,
 %Bookstore.BooksList{
   id: 99,
   method: "books/list",
   params: %Bookstore.BooksListParams{
     query: %{field: "authors", value: "Michael Crichton"},
     order: "desc"
   }
 }}
```

Dumping your internal data model.

```elixir
iex> alias SchematicTest.Bookstore
iex> import Schematic
iex> dump(Bookstore.BooksListResult.schematic(), %Bookstore.BooksListResult{
...>   books: [
...>     %Bookstore.Book{
...>       title: "Jurassic Park",
...>       authors: [%Bookstore.Author{name: "Michael Crichton"}],
...>       publication_date: ~U[1990-11-20 00:00:00.000000Z]
...>     },
...>     %Bookstore.Book{
...>       title: "The Lost World",
...>       authors: [%Bookstore.Author{name: "Michael Crichton"}],
...>       publication_date: ~U[1995-09-08 00:00:00.000000Z]
...>     }
...>   ]
...> })
{:ok,
%{
  "books" => [
    %{
      "authors" => [%{"name" => "Michael Crichton"}],
      "publicationDate" => "1990-11-20T00:00:00.000000Z",
      "title" => "Jurassic Park"
    },
    %{
      "authors" => [%{"name" => "Michael Crichton"}],
      "publicationDate" => "1995-09-08T00:00:00.000000Z",
      "title" => "The Lost World"
    }
  ]
}}
```

<!-- MDOC !-->

## Installation

```elixir
def deps do
  [
    {:schematic, "~> 0.0.10"}
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
