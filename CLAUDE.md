# Claude Code Instructions

Phoenix 1.8 / LiveView homelab management app — Elixir + SQLite. A self-hosted dashboard for managing a home server: monitor and control Docker containers, pull/update Docker Compose services, and view host-level signals (uptime, reboot-required status).

## Architecture

- **`Homelab.Docker`** — talks to the Docker Engine API over the Unix socket (`/var/run/docker.sock`). Lists, starts, stops, restarts containers, and pulls images. Uses an adapter pattern so the adapter can be swapped for a stub in tests.
- **`Homelab.Compose`** — runs `docker compose` CLI commands (pull, up, update). Serializes operations through a lock to prevent concurrent races. Configured via `DOCKER_COMPOSE_FILE_PATH` env var pointing at the compose project directory.
- **`Homelab.HostSignals`** — reads read-only host signals exposed into the container: reboot-required flag (checks `/var/run/reboot-required`) and system uptime.
- **`Homelab.Accounts`** — standard phx.gen.auth user accounts with email magic-link login (no passwords).
- **`HomelabWeb`** — LiveView UI with two main views: Docker services dashboard (`/docker`) and host signals (`/host`). All routes require authentication.

## Dev Setup

The dev compose stack (`dev/docker-compose.yml`) spins up stub services (whoami, nginx) to populate the Docker dashboard during development. Start it with `just dev-up` before running the server. The app itself uses SQLite so no external database is needed.

## Key Commands

| Task | Command |
|------|---------|
| Start dev server | `just server` |
| Run tests | `mix test` |
| Run failing tests only | `mix test --failed` |
| Pre-commit checks (run before finishing) | `mix precommit` |
| Format code | `mix format` |
| Database reset | `mix ecto.reset` |
| Database migrate | `mix ecto.migrate` |

`mix precommit` runs: compile (warnings-as-errors), unused deps check, format, and full test suite. Always run it before finishing any feature.

## Full Project Guidelines

See [AGENTS.md](./AGENTS.md) for Phoenix v1.8, LiveView, Elixir, Ecto, authentication, and UI conventions.
