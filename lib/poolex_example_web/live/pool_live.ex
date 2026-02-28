defmodule PoolexExampleWeb.PoolLive do
  use PoolexExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_tick()

    poolex_version = Application.spec(:poolex, :vsn) |> to_string()
    debug_info = Poolex.Private.DebugInfo.get_debug_info(:demo_pool)

    {:ok,
     assign(socket,
       page_title: "Poolex Dashboard",
       poolex_version: poolex_version,
       debug_info: debug_info,
       occupy_duration: 10
     )}
  end

  @impl true
  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(:demo_pool))}
  end

  @impl true
  def handle_event("add_worker", _params, socket) do
    Poolex.add_idle_workers!(:demo_pool, 1)
    {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(:demo_pool))}
  end

  @impl true
  def handle_event("remove_worker", _params, socket) do
    Poolex.remove_idle_workers!(:demo_pool, 1)
    {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(:demo_pool))}
  end

  @impl true
  def handle_event("occupy", %{"duration" => secs}, socket) do
    case Integer.parse(secs) do
      {n, ""} when n > 0 ->
        ms = n * 1_000

        Task.start(fn ->
          Poolex.run(:demo_pool, fn worker ->
            GenServer.call(worker, {:sleep, ms}, ms + 5_000)
          end)
        end)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, 1_000)
end
