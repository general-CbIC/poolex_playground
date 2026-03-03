defmodule PoolexExampleWeb.PoolLive do
  use PoolexExampleWeb, :live_view

  @pool_id :demo_pool

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_tick()

    poolex_version = Application.spec(:poolex, :vsn) |> to_string()
    debug_info = Poolex.Private.DebugInfo.get_debug_info(@pool_id)
    {milliseconds_from_start, _since_last_call} = :erlang.statistics(:wall_clock)

    {:ok,
     assign(socket,
       acquired_workers: [],
       debug_info: debug_info,
       milliseconds_from_start: milliseconds_from_start,
       occupy_duration: 10,
       page_title: "Poolex Playground",
       poolex_version: poolex_version
     )}
  end

  @impl true
  def handle_info(:tick, socket) do
    schedule_tick()

    debug_info = Poolex.Private.DebugInfo.get_debug_info(@pool_id)
    {milliseconds_from_start, _since_last_call} = :erlang.statistics(:wall_clock)

    {:noreply,
     assign(socket, debug_info: debug_info, milliseconds_from_start: milliseconds_from_start)}
  end

  @impl true
  def handle_event("add_worker", _params, socket) do
    Poolex.add_idle_workers!(@pool_id, 1)
    {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(@pool_id))}
  end

  @impl true
  def handle_event("remove_worker", _params, socket) do
    Poolex.remove_idle_workers!(@pool_id, 1)
    {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(@pool_id))}
  end

  @impl true
  def handle_event("occupy", %{"duration" => secs}, socket) do
    case Integer.parse(secs) do
      {n, ""} when n > 0 ->
        ms = n * 1_000

        Task.start(fn ->
          Poolex.run(@pool_id, fn worker ->
            GenServer.call(worker, {:sleep, ms}, ms + 5_000)
          end)
        end)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("acquire", _params, socket) do
    case Poolex.acquire(@pool_id) do
      {:ok, worker} ->
        acquired_workers = [worker | socket.assigns.acquired_workers]

        {:noreply, assign(socket, acquired_workers: acquired_workers)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("release", _params, socket) do
    case socket.assigns.acquired_workers do
      [worker | acquired_workers] ->
        Poolex.release(@pool_id, worker)

        {:noreply, assign(socket, acquired_workers: acquired_workers)}

      [] ->
        {:noreply, socket}
    end
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, 1_000)
end
