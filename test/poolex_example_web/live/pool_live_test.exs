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

  test "add_worker increases idle count", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    initial = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count

    on_exit(fn -> Poolex.remove_idle_workers!(:demo_pool, 1) end)
    view |> element("button", "Add worker") |> render_click()

    updated = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count
    assert updated == initial + 1
  end

  test "remove_worker decreases idle count", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    initial = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count

    on_exit(fn -> Poolex.add_idle_workers!(:demo_pool, 1) end)
    view |> element("button", "Remove worker") |> render_click()

    updated = Poolex.Private.DebugInfo.get_debug_info(:demo_pool).idle_workers_count
    assert updated == initial - 1
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
end
