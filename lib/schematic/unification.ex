defprotocol Schematic.Unification do
  @moduledoc false
  @fallback_to_any true
  def unify(schematic, value, direction)
  def message(schematic)
end

defimpl Schematic.Unification, for: Schematic do
  def unify(schematic, input, direction) do
    schematic.unify.(input, direction)
  end

  def message(schematic) do
    schematic.message.()
  end
end

defimpl Schematic.Unification, for: Any do
  def unify(literal, value, _ \\ nil) do
    if literal == value do
      {:ok, value}
    else
      {:error, "expected #{inspect(literal)}"}
    end
  end

  def message(literal) do
    inspect(literal)
  end
end
