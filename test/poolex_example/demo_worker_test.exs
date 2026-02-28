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
