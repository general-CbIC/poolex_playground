defmodule PoolexExampleWeb.PageController do
  use PoolexExampleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
