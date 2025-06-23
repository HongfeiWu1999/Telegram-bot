defmodule TelegramBot do
  @moduledoc """
  Documentation for `TelegramBot`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> TelegramBot.hello()
      :world

  """

  use Tesla
  plug Tesla.Middleware.Query, [api_key: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJob25nZmVpLnd1QGFsdW1ub3MudXBtLmVzIiwianRpIjoiYmZmMDc3YjUtZTBjYS00YWYwLTkzZGUtOTQ4MGFhOWU5OGQxIiwiaXNzIjoiQUVNRVQiLCJpYXQiOjE2NTQyNTQ1MTcsInVzZXJJZCI6ImJmZjA3N2I1LWUwY2EtNGFmMC05M2RlLTk0ODBhYTllOThkMSIsInJvbGUiOiIifQ.U9YMevm-wR2t-S2_nKIUuz5ChWoLCrgDXWQVN4l22J8"]
  plug Tesla.Middleware.JSON

  def hello do
    :world
  end

  def test do
    {:ok, table} = :dets.open_file(:"./telegram_bot/province")
    :dets.lookup(table,"Bizkaia")
  end

  def start_work() do
    url = "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/28026"
    {:ok, response} = get url
    url2 = response.body["datos"]
    {:ok, response2} = get url2

    c = latin1_to_utf8(response2.body)
    json2 = Jason.decode! c
    [content] = json2
    c = content["prediccion"]
    content2= c["dia"]
    [a,b,_] = content2
    t1 = a["temperatura"]
    t2 = b["temperatura"]
    IO.puts("T1: #{inspect t1}")
    IO.puts("T2: #{inspect t2}")
  end

  defp latin1_to_utf8(latin1) do
    latin1
    |> :binary.bin_to_list()
    |> :unicode.characters_to_binary(:latin1)
  end

end
