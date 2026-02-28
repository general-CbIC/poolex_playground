# Poolex Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a single-page Phoenix LiveView dashboard for interactively testing Poolex pools — showing version, config, worker states, and controls to add/remove/occupy workers.

**Architecture:** One named Poolex pool (`:demo_pool`) started in `Application`, inspected via `Poolex.Private.DebugInfo.get_debug_info/1`. A LiveView replaces the existing PageController and polls pool state every second via `Process.send_after/3`. Worker occupation runs in a `Task` to avoid blocking the LiveView process.

**Tech Stack:** Elixir, Phoenix 1.8, Phoenix LiveView 1.1, Poolex ~> 1.4, Tailwind CSS

**Worktree:** `.worktrees/poolex-dashboard` (branch: `feature/poolex-dashboard`)

---

### Task 1: Add Poolex dependency

**Files:**
- Modify: `mix.exs`

**Step 1: Add the dependency**

In `mix.exs`, add to the `deps/0` list:

```elixir
{:poolex, "~> 1.4"},
```

**Step 2: Fetch dependencies**

```bash
mix deps.get
```

Expected: Poolex and its deps are downloaded.

**Step 3: Verify compilation**

```bash
mix compile --warnings-as-errors
```

Expected: no errors, `Generated poolex app` in output.

**Step 4: Commit**

```bash
git add mix.exs mix.lock
git commit -m "feat: add poolex ~> 1.4 dependency"
```

---

### Task 2: Create DemoWorker

**Files:**
- Create: `lib/poolex_example/demo_worker.ex`
- Create: `test/poolex_example/demo_worker_test.exs`

**Step 1: Write the failing test**

Create `test/poolex_example/demo_worker_test.exs`:

```elixir
defmodule PoolexExample.DemoWorkerTest do
  use ExUnit.Case, async: true

  alias PoolexExample.DemoWorker

  test "starts successfully" do
    assert {:ok, pid} = DemoWorker.start_link([])
    assert Process.alive?(pid)
  end

  test "sleeps for the given duration" do
    {:ok, pid} = DemoWorker.start_link([])
    start = System.monotonic_time(:millisecond)
    :ok = GenServer.call(pid, {:sleep, 50})
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed >= 50
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/poolex_example/demo_worker_test.exs
```

Expected: `** (UndefinedFunctionError) function PoolexExample.DemoWorker.start_link/1 is undefined`

**Step 3: Implement DemoWorker**

Create `lib/poolex_example/demo_worker.ex`:

```elixir
defmodule PoolexExample.DemoWorker do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_), do: {:ok, nil}

  @impl true
  def handle_call({:sleep, ms}, _from, state) do
    Process.sleep(ms)
    {:reply, :ok, state}
  end
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/poolex_example/demo_worker_test.exs
```

Expected: `2 tests, 0 failures`

**Step 5: Commit**

```bash
git add lib/poolex_example/demo_worker.ex test/poolex_example/demo_worker_test.exs
git commit -m "feat: add DemoWorker GenServer"
```

---

### Task 3: Start the pool in Application

**Files:**
- Modify: `lib/poolex_example/application.ex`

**Step 1: Add the pool to the supervision tree**

In `lib/poolex_example/application.ex`, add the pool child spec to the `children` list (before `PoolexExampleWeb.Endpoint`):

```elixir
{Poolex,
  pool_id: :demo_pool,
  worker_module: PoolexExample.DemoWorker,
  workers_count: 3},
```

**Step 2: Verify the pool starts**

```bash
mix run --no-halt &
sleep 2
curl -s http://localhost:4000 | head -5
kill %1
```

Expected: The server starts without errors. (We'll test the pool more thoroughly in the LiveView tests.)

**Step 3: Verify all tests still pass**

```bash
mix test
```

Expected: `5 tests, 0 failures` (the pool starts in test env too — this is expected).

**Step 4: Commit**

```bash
git add lib/poolex_example/application.ex
git commit -m "feat: start :demo_pool in application supervision tree"
```

---

### Task 4: Create PoolLive — basic mount and display

**Files:**
- Create: `lib/poolex_example_web/live/pool_live.ex`
- Create: `lib/poolex_example_web/live/pool_live.html.heex`
- Modify: `lib/poolex_example_web/router.ex`
- Create: `test/poolex_example_web/live/pool_live_test.exs`

**Step 1: Write failing tests**

Create `test/poolex_example_web/live/pool_live_test.exs`:

```elixir
defmodule PoolexExampleWeb.PoolLiveTest do
  use PoolexExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "mounts and shows Poolex version", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    poolex_version = Application.spec(:poolex, :vsn) |> to_string()
    assert html =~ poolex_version
  end

  test "shows pool configuration", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "DemoWorker"
  end

  test "shows idle workers count", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Idle"
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
mix test test/poolex_example_web/live/pool_live_test.exs
```

Expected: errors about `PoolexExampleWeb.PoolLive` not existing.

**Step 3: Create the LiveView module**

Create `lib/poolex_example_web/live/pool_live.ex`:

```elixir
defmodule PoolexExampleWeb.PoolLive do
  use PoolexExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_tick()

    poolex_version = Application.spec(:poolex, :vsn) |> to_string()
    debug_info = Poolex.Private.DebugInfo.get_debug_info(:demo_pool)

    {:ok,
     assign(socket,
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
  def handle_event("update_duration", %{"duration" => val}, socket) do
    case Integer.parse(val) do
      {n, ""} when n > 0 -> {:noreply, assign(socket, occupy_duration: n)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("occupy", %{"duration" => secs}, socket) do
    ms = String.to_integer(secs) * 1_000

    Task.start(fn ->
      Poolex.run(:demo_pool, fn worker ->
        GenServer.call(worker, {:sleep, ms}, ms + 5_000)
      end)
    end)

    {:noreply, socket}
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, 1_000)
end
```

**Step 4: Create the LiveView template**

Create `lib/poolex_example_web/live/pool_live.html.heex`:

```heex
<div class="max-w-3xl mx-auto py-10 px-4 space-y-8">
  <%!-- Header --%>
  <div>
    <h1 class="text-3xl font-bold text-gray-900">Poolex Dashboard</h1>
    <p class="mt-1 text-sm text-gray-500">
      Poolex <span class="font-mono font-semibold text-indigo-600">v<%= @poolex_version %></span>
    </p>
  </div>

  <%!-- Pool Configuration --%>
  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
    <h2 class="text-lg font-semibold text-gray-700 mb-4">Pool Configuration</h2>
    <dl class="grid grid-cols-2 gap-x-8 gap-y-2 text-sm">
      <dt class="text-gray-500">Worker module</dt>
      <dd class="font-mono text-gray-900"><%= inspect(@debug_info.worker_module) %></dd>

      <dt class="text-gray-500">Worker args</dt>
      <dd class="font-mono text-gray-900"><%= inspect(@debug_info.worker_args) %></dd>

      <dt class="text-gray-500">Max overflow</dt>
      <dd class="font-mono text-gray-900"><%= @debug_info.max_overflow %></dd>

      <dt class="text-gray-500">Shutdown delay</dt>
      <dd class="font-mono text-gray-900"><%= @debug_info.worker_shutdown_delay %> ms</dd>
    </dl>
  </div>

  <%!-- Worker States --%>
  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
    <h2 class="text-lg font-semibold text-gray-700 mb-4">Workers</h2>
    <div class="grid grid-cols-2 gap-6">
      <div>
        <h3 class="text-sm font-medium text-gray-500 mb-2">
          Idle (<%= @debug_info.idle_workers_count %>)
        </h3>
        <div class="space-y-1">
          <%= for pid <- @debug_info.idle_workers_pids do %>
            <span class="inline-block bg-green-100 text-green-800 text-xs font-mono px-2 py-1 rounded">
              <%= inspect(pid) %>
            </span>
          <% end %>
        </div>
      </div>
      <div>
        <h3 class="text-sm font-medium text-gray-500 mb-2">
          Busy (<%= @debug_info.busy_workers_count %>)
        </h3>
        <div class="space-y-1">
          <%= for pid <- @debug_info.busy_workers_pids do %>
            <span class="inline-block bg-orange-100 text-orange-800 text-xs font-mono px-2 py-1 rounded">
              <%= inspect(pid) %>
            </span>
          <% end %>
        </div>
      </div>
    </div>
    <%= if @debug_info.waiting_callers != [] do %>
      <div class="mt-4 text-sm text-red-600">
        Waiting callers: <%= length(@debug_info.waiting_callers) %>
      </div>
    <% end %>
  </div>

  <%!-- Controls --%>
  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
    <h2 class="text-lg font-semibold text-gray-700 mb-4">Controls</h2>
    <div class="flex flex-wrap items-center gap-4">
      <button
        phx-click="add_worker"
        class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700"
      >
        + Add worker
      </button>
      <button
        phx-click="remove_worker"
        class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-300"
      >
        − Remove worker
      </button>

      <form id="occupy-form" phx-submit="occupy" class="flex items-center gap-2">
        <label class="text-sm text-gray-600">Duration:</label>
        <input
          type="number"
          name="duration"
          value={@occupy_duration}
          min="1"
          class="w-20 px-2 py-2 border border-gray-300 rounded-lg text-sm font-mono"
        />
        <span class="text-sm text-gray-500">sec</span>
        <button
          type="submit"
          class="px-4 py-2 bg-amber-500 text-white text-sm font-medium rounded-lg hover:bg-amber-600"
        >
          Occupy worker
        </button>
      </form>
    </div>
  </div>
</div>
```

**Step 5: Update the router**

In `lib/poolex_example_web/router.ex`, replace:

```elixir
get "/", PageController, :home
```

with:

```elixir
live "/", PoolLive
```

**Step 6: Run tests**

```bash
mix test test/poolex_example_web/live/pool_live_test.exs
```

Expected: `3 tests, 0 failures`

**Step 7: Run all tests**

```bash
mix test
```

Note: The old `PageControllerTest` will now fail because `/` no longer returns "Peace of mind from prototype to production". **Delete** `test/poolex_example_web/controllers/page_controller_test.exs` — that test is replaced by the LiveView tests.

```bash
rm test/poolex_example_web/controllers/page_controller_test.exs
mix test
```

Expected: all tests pass.

**Step 8: Commit**

```bash
git add lib/poolex_example_web/live/ lib/poolex_example_web/router.ex
git rm test/poolex_example_web/controllers/page_controller_test.exs
git commit -m "feat: add PoolLive dashboard at /"
```

---

### Task 5: Test worker management events

**Files:**
- Modify: `test/poolex_example_web/live/pool_live_test.exs`

**Step 1: Add event tests**

Append to `test/poolex_example_web/live/pool_live_test.exs`:

```elixir
test "add_worker increases idle count", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  initial = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count

  view |> element("button", "+ Add worker") |> render_click()

  send(view.pid, :tick)
  html = render(view)

  updated = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count
  assert updated == initial + 1

  # Clean up: remove the worker we added
  Poolex.remove_idle_workers!(:demo_pool, 1)
end

test "remove_worker decreases idle count", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  initial = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count

  view |> element("button", "− Remove worker") |> render_click()

  updated = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count
  assert updated == initial - 1

  # Clean up: restore removed worker
  Poolex.add_idle_workers!(:demo_pool, 1)
end

test "occupy submits without error", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")

  view
  |> form("#occupy-form", %{duration: "1"})
  |> render_submit()

  # Give the task a moment to start, then verify LiveView is still alive
  Process.sleep(100)
  assert Process.alive?(view.pid)
end
```

**Step 2: Run tests**

```bash
mix test test/poolex_example_web/live/pool_live_test.exs
```

Expected: `6 tests, 0 failures`

**Step 3: Run full suite**

```bash
mix test
```

Expected: all tests pass.

**Step 4: Commit**

```bash
git add test/poolex_example_web/live/pool_live_test.exs
git commit -m "test: add worker management and occupy event tests"
```

---

### Task 6: Final check and cleanup

**Step 1: Run precommit alias**

```bash
mix precommit
```

Expected: `mix compile --warnings-as-errors` passes, `mix format` has no changes, all tests pass.

**Step 2: If format reports changes, fix them**

```bash
mix format
git add -A
git commit -m "style: apply mix format"
```

**Step 3: Verify the app runs**

```bash
mix phx.server
```

Open `http://localhost:4000` — confirm:
- Poolex version shows
- Pool config shows (DemoWorker, 0 max_overflow, etc.)
- 3 idle workers with PIDs shown as green badges
- "+ Add worker" and "− Remove worker" buttons work in real time
- "Occupy worker" button with duration input turns workers orange while busy
