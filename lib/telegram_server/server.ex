defmodule MyServer do
  use GenServer

  use Tesla
  plug Tesla.Middleware.Query, [api_key: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJob25nZmVpLnd1QGFsdW1ub3MudXBtLmVzIiwianRpIjoiYmZmMDc3YjUtZTBjYS00YWYwLTkzZGUtOTQ4MGFhOWU5OGQxIiwiaXNzIjoiQUVNRVQiLCJpYXQiOjE2NTQyNTQ1MTcsInVzZXJJZCI6ImJmZjA3N2I1LWUwY2EtNGFmMC05M2RlLTk0ODBhYTllOThkMSIsInJvbGUiOiIifQ.U9YMevm-wR2t-S2_nKIUuz5ChWoLCrgDXWQVN4l22J8"]
  plug Tesla.Middleware.JSON

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_cast({:monitor, municipality, value, sign, temperature, chat_id, hour}, state) do
    # Work information into a tuple
    work = {chat_id, municipality, value, sign, temperature, hour}
    # Schedule work's finish time
    schedule_finish(work)
    IO.puts("Monitoring: chat_id #{inspect chat_id}, municipality #{inspect municipality}, value #{inspect value}")
    IO.puts("Monitoring: sign #{inspect sign}, temperature #{inspect temperature}, hour #{inspect hour}")
    # Add work into the queue
    {:noreply, [work|state]}
  end

  @impl true
  def handle_info(:work, state) do
    # Check the temperatures
    start_work(state)
    # Program the next review in 30 minutes
    schedule_work()
    {:noreply, state}
  end

  @impl true
  def handle_info({:finish, work}, state) do
    # Work is finish
    {chat_id, municipality, value, sign, temperature, hour} = work
    IO.puts("FINISH: chat_id #{inspect chat_id}, municipality #{inspect municipality}, value #{inspect value}")
    IO.puts("FINISH: sign #{inspect sign}, temperature #{inspect temperature}, hour #{inspect hour}")
    {:noreply, delete_work(state, work)}
  end

  defp schedule_work() do
    # We schedule the work to happen every 30 minutes (written in milliseconds).
    Process.send_after(self(), :work, 30 * 60 * 1000)
  end

  defp schedule_finish(work) do
    # We schedule the work to finish after 6 hours (written in milliseconds).
    {chat_id, municipality, value, sign, temperature, hour} = work
    IO.puts("Scheduled: chat_id #{inspect chat_id}, municipality #{inspect municipality}, value #{inspect value}")
    IO.puts("Scheduled: sign #{inspect sign}, temperature #{inspect temperature}, hour #{inspect hour}")
    Process.send_after(self(), {:finish, work}, 6 * 60 * 60 * 1000)
  end

  defp delete_work([], _) do
    []
  end

  defp delete_work([head|tail], work) do
    {chat_id, municipality, value, sign, temperature, hour} = work
    {id, m, v, s, t, h} = head
    if String.equivalent?(id, chat_id) and String.equivalent?(m, municipality) and String.equivalent?(v, value) and
       String.equivalent?(s, sign) and temperature == t and hour == h do
      tail
    else
      [ head | delete_work(tail, work) ]
    end
  end

  defp start_work([]) do
    []
  end

  defp start_work([h|t]) do
    {chat_id, municipality, value, sign, temperature, hour} = h

    url = "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/#{value}"
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

    {_,{h,_,_}} = :calendar.local_time()

    if String.equivalent?(sign, ">") do
      list = list_search(t1,hour)
      case list do
        [] -> compare_greater_temperature(t2, municipality, 6-get_difference(hour,h,0), temperature, chat_id)
        _ ->
          n = compare_greater_temperature(list, municipality, 6-get_difference(hour,h,0), temperature, chat_id)
          if n > 0 do
            compare_greater_temperature(t2, municipality, n, temperature, chat_id)
          end
      end
    else
      list = list_search(t1,hour)
      case list do
        [] -> compare_less_temperature(t2, municipality, 6-get_difference(hour,h,0), temperature, chat_id)
        _ ->
          n = compare_less_temperature(list, municipality, 6-get_difference(hour,h,0), temperature, chat_id)
          if n > 0 do
            compare_less_temperature(t2, municipality, n, temperature, chat_id)
          end
      end
    end
    start_work(t)
  end

  defp latin1_to_utf8(latin1) do
    latin1
    |> :binary.bin_to_list()
    |> :unicode.characters_to_binary(:latin1)
  end

  defp compare_greater_temperature([], _, cont, _, _) do
    cont
  end

  defp compare_greater_temperature([_], _, 0, _, _) do
    0
  end

  defp compare_greater_temperature([h|t], municipality, cont, temperature, chat_id) do
    {_,{ch,_,_}} = :calendar.local_time()
    hour = String.to_integer(h["periodo"]) - ch
    temp = String.to_integer(h["value"])
    if temp > temperature do
      ExGram.send_message(chat_id,"Alert, #{temp}°C in #{hour} at #{municipality}")
    end
    compare_greater_temperature(t, municipality, cont-1, temperature, chat_id)
  end

  defp compare_less_temperature([], _, cont, _, _) do
    cont
  end

  defp compare_less_temperature([_], _, 0, _, _) do
    0
  end

  defp compare_less_temperature([h|t], municipality, cont, temperature, chat_id) do
    {_,{ch,_,_}} = :calendar.local_time()
    hour = String.to_integer(h["periodo"]) - ch
    temp = String.to_integer(h["value"])
    if temp < temperature do
      ExGram.send_message(chat_id,"Alert, #{temp}°C in #{hour} at #{municipality}")
    end
    compare_less_temperature(t, municipality, cont-1, temperature, chat_id)
  end

  defp get_difference(hour,next,cont) do
    h = rem(hour+1, 24)
    get_difference(h,next,cont+1)
  end

  defp list_search([],_) do
    []
  end

  defp list_search([h|t],hour) do
    periodo = String.to_integer(h["periodo"])
    if periodo == hour do
      [h|t]
    else
      list_search(t,hour)
    end
  end

end
