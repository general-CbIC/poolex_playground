# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Poolex Playground — a single-page Phoenix LiveView app that acts as an interactive test stand for the
[Poolex](https://github.com/general-CbIC/poolex) worker-pool library. Deployed at
<https://poolex-playground.cbic-dev.com/> (Fly.io). No database, no auth, no Ecto.

`AGENTS.md` holds the detailed Phoenix/Elixir/HEEx/LiveView coding rules for this repo — follow them; they are
not repeated here.

## Commands

```bash
mix setup            # deps.get + assets.setup + assets.build (run once after clone)
mix phx.server       # dev server on http://localhost:4000 (esbuild + tailwind watchers included)
iex -S mix phx.server

mix precommit        # REQUIRED before finishing changes: compile --warnings-as-errors, deps.unlock --unused, format, test
mix test
mix test test/poolex_example_web/live/pool_live_test.exs        # single file
mix test test/poolex_example_web/live/pool_live_test.exs:12     # single test by line
mix test --failed
mix format
```

Toolchain is pinned in `.tool-versions` (Erlang 28.4.1 / Elixir 1.19.5-otp-28). `mix precommit` runs in `:test`
env via the `cli/0` `preferred_envs` setting.

## Architecture

The whole app is three moving parts:

1. **`PoolexExample.Application`** (`lib/poolex_example/application.ex`) starts a single named Poolex pool,
   `:demo_pool`, in the supervision tree (`workers_count: 3`, `max_overflow: 5`, `min_pool_size: 3`,
   `max_pool_size: 10`). Changing pool behaviour for the demo means editing this child spec.
2. **`PoolexExample.DemoWorker`** (`lib/poolex_example/demo_worker.ex`) — a deliberately trivial GenServer whose
   only job is `handle_call({:sleep, ms}, ...)`, so the UI can hold a worker busy for a chosen duration.
3. **`PoolexExampleWeb.PoolLive`** (`lib/poolex_example_web/live/pool_live.ex` + `.html.heex`) — the only route
   (`live "/"` in the router). It is the entire UI.

Key LiveView behaviours worth knowing before editing `PoolLive`:

- Pool state is read with `Poolex.Private.DebugInfo.get_debug_info(:demo_pool)` — a **private** Poolex API. It
  can change shape between Poolex releases; the assigns (`idle_workers_pids`, `busy_workers_count`,
  `waiting_callers`, …) come straight from that struct.
- State is **polled**, not pushed: `schedule_tick/0` re-arms `Process.send_after(self(), :tick, 1_000)` from
  `mount/3` (only when `connected?/1`) and from every `handle_info(:tick, ...)`. There is no PubSub.
- The `"occupy"` event runs `Poolex.run/2` inside `Task.start/1` on purpose — blocking the LiveView process
  would freeze the page it is meant to visualise.
- `"acquire"`/`"release"` keep a manual LIFO stack of checked-out workers in the `:acquired_workers` assign;
  those workers stay busy until released, which is how the UI demonstrates pool exhaustion.

`page_controller.ex` / `page_html/home.html.heex` are leftover Phoenix scaffolding and are not routed.

## Assets

esbuild + Tailwind v4 (no `tailwind.config.js`), configured in `config/config.exs` under the `:poolex_example`
profile name. `assets/vendor/` carries vendored daisyUI, heroicons and topbar; there is no `package.json` or
npm install step. `mix assets.deploy` is what the Docker build runs.

## Deployment

Push to `main` triggers `.github/workflows/fly-deploy.yml` → `flyctl deploy --remote-only`, building the
multi-stage `Dockerfile` (`mix assets.deploy` + `mix release`, started via `CMD /app/bin/server`, the
`rel/overlays/bin/server` script that sets `PHX_SERVER=true`). `PHX_HOST` and `PORT` come from `fly.toml`;
`SECRET_KEY_BASE` must be a Fly secret or the app refuses to boot. New public hostnames must also be added to the `check_origin` list in `config/config.exs`,
otherwise the LiveView websocket is rejected.

## Planning docs

`docs/plans/` holds dated design + implementation-plan markdown for larger features. Follow the same
`YYYY-MM-DD-<topic>-{design,plan}.md` convention when adding new ones.
