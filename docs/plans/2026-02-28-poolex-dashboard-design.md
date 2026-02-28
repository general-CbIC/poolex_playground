# Poolex Dashboard — Design

## Goal

An interactive single-page Phoenix LiveView application that serves as a test stand for new versions of the Poolex library.

## Dependencies

Add to `mix.exs`:

```elixir
{:poolex, "~> 1.4"}
```

## Architecture

### Components

1. **`PoolexExample.DemoWorker`** — GenServer that accepts `{:sleep, ms}` calls to simulate work.

2. **`:demo_pool`** — Named Poolex pool started in `PoolexExample.Application`, initially configured with 3 workers.

3. **`PoolexExampleWeb.PoolLive`** — LiveView at `/` that replaces the current `PageController`. Polls pool state every second using `Process.send_after/3`.

4. **State inspection** — `Poolex.Private.DebugInfo.get_debug_info(:demo_pool)` for reading pool state.

5. **Version** — `Application.spec(:poolex, :vsn)` for displaying installed Poolex version.

### Pool Configuration (initial)

```elixir
{Poolex,
  pool_id: :demo_pool,
  worker_module: PoolexExample.DemoWorker,
  workers_count: 3}
```

## UI Layout

### Block 1 — Pool Info

Displays installed Poolex version and pool configuration fields from `DebugInfo`:
- `worker_module`
- `worker_args`
- `max_overflow`
- `worker_shutdown_delay`

### Block 2 — Worker State

Two columns of PID badges, updated every second:
- **Idle** — green badges, count shown in header
- **Busy** — orange badges, count shown in header
- **Waiting callers** — shown if `waiting_callers` is non-empty

### Block 3 — Controls

- `[+ Add worker]` button — calls `Poolex.add_idle_workers!(:demo_pool, 1)`
- `[- Remove worker]` button — calls `Poolex.remove_idle_workers!(:demo_pool, 1)`
- Duration input (seconds) + `[Occupy worker]` button

## Data Flow

### LiveView assigns

```elixir
%{
  debug_info: %Poolex.Private.DebugInfo{},  # updated every second
  poolex_version: "1.4.2",                  # static, set at mount
  occupy_duration: 10                        # user input value
}
```

### Periodic refresh

```elixir
def mount(_, _, socket) do
  if connected?(socket), do: schedule_tick()
  {:ok, assign(socket, ...)}
end

def handle_info(:tick, socket) do
  schedule_tick()
  {:noreply, assign(socket, debug_info: Poolex.Private.DebugInfo.get_debug_info(:demo_pool))}
end

defp schedule_tick, do: Process.send_after(self(), :tick, 1_000)
```

### Occupy worker

Runs in a `Task` to avoid blocking the LiveView process:

```elixir
def handle_event("occupy", %{"duration" => secs}, socket) do
  ms = String.to_integer(secs) * 1_000
  Task.start(fn ->
    Poolex.run(:demo_pool, fn worker ->
      GenServer.call(worker, {:sleep, ms}, ms + 5_000)
    end)
  end)
  {:noreply, socket}
end
```

### Add / Remove workers

Synchronous calls in `handle_event`:

```elixir
def handle_event("add_worker", _, socket) do
  Poolex.add_idle_workers!(:demo_pool, 1)
  {:noreply, socket}
end

def handle_event("remove_worker", _, socket) do
  Poolex.remove_idle_workers!(:demo_pool, 1)
  {:noreply, socket}
end
```
