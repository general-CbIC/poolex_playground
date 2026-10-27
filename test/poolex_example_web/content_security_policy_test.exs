defmodule PoolexExampleWeb.ContentSecurityPolicyTest do
  use PoolexExampleWeb.ConnCase, async: true

  test "sets a nonce-based CSP that allows the inline theme script", %{conn: conn} do
    conn = get(conn, "/")

    [policy] = get_resp_header(conn, "content-security-policy")
    [_, nonce] = Regex.run(~r/script-src 'self' 'nonce-([^']+)'/, policy)

    assert html_response(conn, 200) =~ ~s(<script nonce="#{nonce}">)
  end

  test "generates a fresh nonce per request", %{conn: conn} do
    [first] = conn |> get("/") |> get_resp_header("content-security-policy")
    [second] = build_conn() |> get("/") |> get_resp_header("content-security-policy")

    refute first == second
  end
end
