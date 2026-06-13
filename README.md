# Homelab

Self-hosted dashboard for managing a home server. Built with Phoenix 1.8 / LiveView + SQLite.

## Features

- **Docker dashboard** — view, start, stop, restart containers; pull updated images
- **Compose management** — pull and recreate individual services or the entire stack
- **Host signals** — uptime and reboot-required status from the host
- **Auth** — magic-link email login (no passwords)

## Dev Setup

Requires Elixir 1.19.5 + OTP 28. Install via [mise](https://mise.jdx.dev/):

```bash
mise install        # picks up .mise.toml
mix setup           # deps + DB
just dev-up         # start stub Docker services
just server         # start Phoenix
```

Visit `http://localhost:4000`.

## Common Commands

```bash
just server         # Phoenix dev server (sets DOCKER_COMPOSE_FILE_PATH)
mix test            # run tests
mix test --failed   # re-run failures only
mix precommit       # compile + format + test (run before committing)
just dev-up         # start dev compose stack (whoami + nginx stubs)
just dev-down       # stop dev compose stack
```

## Architecture

| Module | Responsibility |
|--------|---------------|
| `Homelab.Docker` | Docker Engine API over Unix socket (`/var/run/docker.sock`) |
| `Homelab.Compose` | `docker compose` CLI operations, serialized via a lock |
| `Homelab.HostSignals` | Host-level signals (uptime, reboot-required) |
| `Homelab.Accounts` | User accounts via phx.gen.auth |
| `HomelabWeb` | LiveView UI — `/docker` and `/host` (all routes require auth) |

## Docker in Tests

`Homelab.Docker` and `Homelab.Compose` use an adapter/runner behaviour pattern. Tests use stubs configured in `config/test.exs` — no real Docker socket needed.
