defimpl Inspect, for: Schematic do
  def inspect(schematic, opts) do
    schematic.inspect.(nil, opts) |> Code.format_string!() |> IO.iodata_to_binary()
  end
end

defimpl Inspect, for: Schematic.OptionalKey do
  def inspect(optional_key, _opts) do
    default =
      if optional_key.default do
        ", #{inspect(optional_key.default)}"
      else
        ""
      end

    "optional(#{inspect(optional_key.key)}#{default})"
  end
end
