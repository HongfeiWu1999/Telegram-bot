defmodule TelegramBot.Bot do
  @bot :telegram_bot

  use ExGram.Bot,
    name: @bot,
    setup_commands: true

  use Tesla
  plug Tesla.Middleware.Query, [api_key: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJob25nZmVpLnd1QGFsdW1ub3MudXBtLmVzIiwianRpIjoiYmZmMDc3YjUtZTBjYS00YWYwLTkzZGUtOTQ4MGFhOWU5OGQxIiwiaXNzIjoiQUVNRVQiLCJpYXQiOjE2NTQyNTQ1MTcsInVzZXJJZCI6ImJmZjA3N2I1LWUwY2EtNGFmMC05M2RlLTk0ODBhYTllOThkMSIsInJvbGUiOiIifQ.U9YMevm-wR2t-S2_nKIUuz5ChWoLCrgDXWQVN4l22J8"]
  plug Tesla.Middleware.JSON

  command("start")
  command("help", description: "Print the bot's help")
  command("forecast", description: "Example of use of forecast")

  middleware(ExGram.Middleware.IgnoreUsername)

  def bot(), do: @bot

  def handle({:command, :start, _msg}, context) do
    answer(context, get_introduction())
  end

  def handle({:command, :help, _msg}, context) do
    answer(context, get_help())
  end

  def handle({:command, :forecast, _msg}, context) do
    answer(context, get_forecast_example())
  end

  def handle({:text, text, msg}, context) do
    {_,{hour,_,_}} = :calendar.local_time()
    %{chat: %{id: chat_id}} = msg
    case text do
      "forecast " <> province -> answer(context, get_forecast(province))
      "alert " <> right -> answer(context, monitor_temperature(right,chat_id,hour+1))
      _ -> answer(context, "Command not found, more information: /help")
    end
  end

  def get_introduction() do
    """
      This bot receive the following inputs:
      Typing a message with forecast followed by the
      name of the provincce, the bot will response
      you with the forecast for that region.

      Note that provinces and municipalities always
      start with a capital letter, and accents are
      important.
    """
  end

  def get_help() do
    """
      This bot has the following commands:
      /start - Get Bot's Introduction
      /help - Get Bot's Commands
      /forecast - Get Example of Use
    """
  end

  def get_forecast_example() do
    """
      To know the weather information
      of a province, you have to enter
      forecast followed by the province.
      Example:
      User: forecast Bizkaia
      Bot: PREDICCION PARA BIZKAIA

      BIZKAIA
      Predominio de cielo nuboso
    """
  end

  def get_forecast(province) do

    {:ok, table} = :dets.open_file(:"./lib/telegram_bot/province")
    content = :dets.lookup(table, province)
    case content do
      []  ->  "The province does not exist"
      _   ->
        [{_, value}] = content
        url = "https://opendata.aemet.es/opendata/api/prediccion/provincia/hoy/#{value}"
        {:ok, response} = get url
        url2 = response.body["datos"]
        {:ok, response2} = get url2
        latin1_to_utf8(response2.body)
    end

  end

  def monitor_temperature(information, chat_id, hour) do

    content = String.split(information," ")
    case content do
      [municipality, sign, temperature] ->
        {:ok, table} = :dets.open_file(:"./lib/telegram_bot/municipality")
        content = :dets.lookup(table, municipality)
        if content != [] do
          temperature = String.to_integer(temperature)
          if String.equivalent?(sign, ">") or String.equivalent?(sign, "<") do
            [{_,value}] = content
            GenServer.cast(MyServer,{:monitor, municipality, value, sign, temperature, chat_id, hour})
            "Monitoring municipality \"" <> municipality <> "\" for the next 6 hours"
          else
            "Incorrect format, correct format-> \"alert Used > 20\" "
          end
        else
          "The municipality does not found"
        end
      _ -> "Incorrect format, correct format-> \"alert Used > 20\" "
    end

  end

  defp latin1_to_utf8(latin1) do
    latin1
    |> :binary.bin_to_list()
    |> :unicode.characters_to_binary(:latin1)
  end

end
