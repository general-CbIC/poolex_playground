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
