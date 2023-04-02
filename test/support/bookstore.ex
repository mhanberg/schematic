defmodule SchematicTest.Bookstore do
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
        {"publicationDate", :publication_date} => SchematicTest.Bookstore.Datetime.schematic(),
        title: str(),
        authors: list(SchematicTest.Bookstore.Author.schematic())
      })
    end
  end

  defmodule BooksListResult do
    import Schematic

    defstruct [:books]

    def schematic() do
      schema(__MODULE__, %{
        books: list(SchematicTest.Bookstore.Book.schematic())
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
        params: SchematicTest.Bookstore.BooksListParams.schematic()
      })
    end
  end
end
