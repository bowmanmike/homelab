# Development Compose Stack

A minimal Docker Compose stack for testing compose commands locally.

## Usage

Start the dev stack:

```bash
docker compose -f dev/docker-compose.yml up -d
```

Stop it:

```bash
docker compose -f dev/docker-compose.yml down
```

## Configure Homelab to use it

Set the env var before running `mix phx.server`:

```bash
export DOCKER_COMPOSE_FILE_PATH="$(pwd)/dev"
mix phx.server
```

Or add it to a `.env` file (not committed).

## Services

- **whoami** — Simple HTTP server that returns request info (port 8081)
- **nginx** — Basic nginx server (port 8082)

Both are lightweight and quick to pull/restart for testing the Update flow.
