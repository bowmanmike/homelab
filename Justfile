# List available commands
default:
    @just --list

# Start the dev compose stack
dev-up:
    docker compose -f dev/docker-compose.yml up -d

# Stop the dev compose stack
dev-down:
    docker compose -f dev/docker-compose.yml down

# Run Phoenix server with dev compose path
server:
    DOCKER_COMPOSE_FILE_PATH="{{justfile_directory()}}/dev" iex -S mix phx.server

# Start everything (compose + phoenix)
dev: dev-up server

# Run tests
test:
    mix test

# Run precommit checks
check:
    mix precommit

# Interactive Elixir shell with Phoenix
console:
    DOCKER_COMPOSE_FILE_PATH="{{justfile_directory()}}/dev" iex -S mix phx.server
