# required for versions of Elixir < 1.11
{:ok, _} = Application.ensure_all_started(:stream_data)

ExUnit.start()
