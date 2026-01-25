# Homelab Control Plane – Architecture & Design Notes

## Overview

Homelab Control Plane is a single-node operator console built in **Elixir**
with a **Phoenix + LiveView UI** and an integrated execution supervisor. It
runs inside the same Docker Compose stack as the services it manages, mounts
`/var/run/docker.sock`, and provides a safe alternative to SSH for routine
operations.

The deployment is:

- LAN / Tailscale only
- Single-user (with Phoenix-authenticated access)
- Explicitly allowlisted (no arbitrary command execution)
- Designed for long-running supervision, real-time feedback, and safety

It prioritizes:

- Observability (logs, status, history, host signals)
- Correctness under failure
- Low operational complexity
- Clear security boundaries despite socket-level privileges

---

## Architecture

All capabilities live inside a single OTP application:

- **Phoenix / LiveView UI**
  - Authentication (`phx.gen.auth`, self-registration disabled)
  - Operations dashboard and host insights
  - Real-time log streaming
  - Audit and execution history

- **Execution Supervisor (OTP processes)**
  - Executes allowlisted commands
  - Supervises execution lifecycles
  - Streams output incrementally
  - Enforces locking, concurrency, and timeouts

The UI issues high-level intents. Execution modules perform the work via
controlled shell/Docker interactions. No part of the system accepts raw shell
input or arbitrary Docker API requests.

### Command Model

Each operation maps to a dedicated Elixir module/function such as
`Homelab.Commands.DockerPullAll.run/1`. All shell and Docker calls pass through
these modules so we can audit, test, and constrain behavior. Commands cover:

- Docker operations (pull, recreate, restart, inspect, logs, health)
- Host telemetry (disk usage, network reachability probes, reboot-required
  flag, unattended-upgrade status, journalctl slices)
- Host actions (reboot, reload services) where explicitly allowed

Future composite workflows will orchestrate these primitives, but v1 keeps
commands small and atomic.

---

## Core Design Principles

### 1. No Arbitrary Commands

All actions are modeled as typed operations rather than free-form commands.
Examples include:

- `docker_pull_all`
- `docker_up_all`
- `docker_restart(service)`
- `docker_logs(service, tail, follow)`
- `backup_run`
- `host_disk_report`
- `host_network_probe`
- `host_reboot_required`
- `host_reboot`

There is no mechanism for passing user-supplied shell strings or parameters.
Command arguments are explicitly validated before execution.

---

### 2. Docker-First, Host-Conscious

Version 1 focuses on Docker-level operations while exposing key host signals:

- Pull images (single + bulk)
- Recreate the compose stack
- Restart individual services
- Stream container logs
- Display container health and status
- Surface disk usage summaries
- Show network reachability (e.g., upstream ping, DNS probe)
- Flag reboot-required and report unattended-upgrade results
- Tail targeted journalctl units

Host-level actions remain minimal and must map to a single explicit command
(e.g., `host_reboot`). Most maintenance continues to live in host-owned
systemd services/scripts; the control plane can observe or trigger them but not
arbitrarily mutate the host.

---

### 3. Explicit Safety Boundaries

Despite socket-level access, the system tightens safety via:

- Non-root container user whenever possible
- Mounting only the Docker socket and required volumes
- Centralized command modules (no ad-hoc `System.cmd/3` usage)
- Strict argument validation (container names, journal units, etc.)
- Audit logging for every execution, including failure details

Safety relies on code discipline rather than Docker labels; the control plane
can operate on any container on the host, so all commands must be carefully
reviewed.

---

### 4. Single-Node Persistence with SQLite

SQLite is used for:

- Operation history
- Audit logs
- Execution metadata (duration, exit status)

Rationale:

- Single-node deployment
- Very low write concurrency
- Simplified backups (single file)
- Zero operational overhead

The database file lives on a host-mounted volume already captured by an
existing systemd/restic backup timer. Future iterations may ingest the backup
logs to verify freshness from within the UI.

---

## Execution Model

Each operation run:

- Executes in its own supervised process
- Has a hard timeout
- Is subject to concurrency limits
- May be protected by single-flight locks (e.g. only one stack recreation at a
  time)

All operations emit structured lifecycle events and capture logs. Results are
persisted regardless of success or failure.

Failures are isolated and never wedge the system.

---

## Log Streaming

Log streaming is implemented using:

- A supervised process running `docker logs -f`
- Line-by-line output streaming
- PubSub delivery to LiveView subscribers

Logs are:

- Treated as untrusted text
- Escaped by default
- Capped in storage (e.g. last N lines per operation)

---

## Development Setup (macOS)

- Development OS: macOS with Docker Desktop
- Phoenix runs natively (`mix phx.server`)
- The execution layer connects to the local Docker daemon
- A dedicated `homelab-dev` Docker Compose stack (services for logs, health,
  restarts) is used for testing

### Development Safety Rules

- Only spin up the dev compose file (`homelab-dev` project name) locally
- Mirror production labels/env vars where helpful, but keep the stack isolated
- No commands may target production contexts during development (set
  `DOCKER_HOST`/env guards to point to dev)

This provides realistic Docker interactions without running the control plane
inside containers during development.

---

## Production Deployment

- Phoenix and the execution supervisor run in a single container
- `/var/run/docker.sock` is mounted into the container
- The container runs as a non-root user when possible, with only required host
  volumes (SQLite, configuration, logs)
- LAN or Tailscale-only exposure via reverse proxy or direct port binding
- Authentication and audit logging are mandatory
- Future host integrations (unattended upgrades, reboot-required flags) rely on
  host scripts/systemd units the container can observe or trigger

---

## Why Elixir

Elixir is chosen because this system is:

- Long-running
- Stateful
- Failure-prone due to external dependencies
- Log- and event-heavy
- Naturally concurrent

OTP supervision, message passing, and LiveView simplify coordination and
recovery compared to shell scripts or ad-hoc tooling. Embedding the execution
agent directly inside Phoenix keeps architecture simple and reduces the number
of deployable artifacts.

---

## Non-Goals

The system explicitly does not aim to:

- Orchestrate multiple hosts
- Execute arbitrary commands
- Expose public internet access
- Replace configuration management tools
- Provide high availability or clustering

---

## Future Extensions (Optional)

- Backup orchestration and visualization
- Health trend analysis
- Drift detection (compose configuration vs runtime state)
- Notifications (ntfy, email)
- Host maintenance via host-owned scripts

All future features must preserve the allowlist and audit model.

---

## Summary

This project is intentionally boring, explicit, and opinionated.

Its purpose is to replace routine SSH usage with a safe, observable, real-time
control plane. If a feature feels convenient but dangerous, it is likely out of
scope.
