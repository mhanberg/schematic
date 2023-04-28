defmodule SchematicTest.Generators do
  import StreamData

  def json_primitive() do
    one_of([
      binary(),
      integer(),
      float(),
      boolean(),
      constant(nil)
    ])
  end

  def json_value do
    one_of([
      json_primitive(),
      map_of(binary(), json_primitive()),
      list_of(json_primitive())
    ])
  end
end
