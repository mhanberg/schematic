# required for versions of Elixir < 1.11

Application.put_env(
  :stream_data,
  :max_runs,
  System.get_env("MAX_RUNS", "100") |> String.to_integer()
)

{:ok, _} = Application.ensure_all_started(:stream_data)

timeout =
  case System.get_env("TIMEOUT", "60000") do
    "infinity" -> :infinity
    num -> String.to_integer(num)
  end

ExUnit.start(timeout: timeout)
