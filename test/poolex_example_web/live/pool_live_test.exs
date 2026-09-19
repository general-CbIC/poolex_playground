defmodule PoolexExampleWeb.PoolLiveTest do
  use PoolexExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @pool_id :demo_pool
  @timeout 2_000
  @poll_interval 10

  # The pool is global state shared by the whole suite, so every test starts
  # from a quiet pool and puts back exactly what it changed.
  setup do
    wait_for_idle_pool()
    :ok
  end

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

  test "add_worker increases idle count", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    baseline = idle_workers_count()
    on_exit(fn -> restore_pool_size(baseline) end)

    view |> element("button", "Add worker") |> render_click()

    assert idle_workers_count() == baseline + 1
  end

  test "remove_worker decreases idle count", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    baseline = idle_workers_count()
    on_exit(fn -> restore_pool_size(baseline) end)

    # The pool boots at min_pool_size, where removal is refused by design, so
    # lift it above the floor before exercising the button.
    Poolex.add_idle_workers!(@pool_id, 1)
    initial = idle_workers_count()

    view |> element("button", "Remove worker") |> render_click()

    assert idle_workers_count() == initial - 1
  end

  test "shows the Aviasales sponsor logo linking to the sponsor page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(
             view,
             ~s(#sponsor-aviasales[href="https://aviasales.tpo.mx/bNjfn4k9"][target="_blank"])
           )

    assert has_element?(view, ~s(#sponsor-aviasales img[alt="Aviasales"]))
  end

  test "occupy submits without error", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#occupy-form", %{duration: "1"})
    |> render_submit()

    assert wait_until(fn -> busy_workers_count() > 0 end),
           "submitting the occupy form did not put any worker to work"

    assert Process.alive?(view.pid)

    # The task holds its worker for a full second; wait it out so the busy
    # worker does not leak into the next test.
    wait_for_idle_pool()
  end

  defp debug_info, do: Poolex.Private.DebugInfo.get_debug_info(@pool_id)

  defp idle_workers_count, do: debug_info().idle_workers_count

  defp busy_workers_count, do: debug_info().busy_workers_count

  defp wait_for_idle_pool do
    assert wait_until(fn -> busy_workers_count() == 0 end),
           "pool still had busy workers after #{@timeout}ms"
  end

  # Puts the pool back to `baseline` idle workers whether or not the action
  # under test actually went through.
  defp restore_pool_size(baseline) do
    wait_for_idle_pool()

    case idle_workers_count() - baseline do
      0 -> :ok
      extra when extra > 0 -> Poolex.remove_idle_workers!(@pool_id, extra)
      missing -> Poolex.add_idle_workers!(@pool_id, -missing)
    end
  end

  defp wait_until(fun) do
    wait_until(fun, System.monotonic_time(:millisecond) + @timeout)
  end

  defp wait_until(fun, deadline) do
    cond do
      fun.() ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(@poll_interval)
        wait_until(fun, deadline)
    end
  end
end
