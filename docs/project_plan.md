# Homelab Control Plane – Project Plan

## Current Status

- Phoenix app skeleton with `phx.gen.auth` is in place and self-registration is disabled.
- Initial dev user exists for validating authenticated flows.
- Architecture goals (single-node, allowlisted commands, SQLite persistence) are captured in `docs/architecture.md`.
- `/var/run/docker.sock` is mounted into the Homelab container, the runtime user belongs to the host `docker` group, and the dashboard now renders the live list of containers pulled via Req from the Engine API (including error badges/tests).

## Workstreams & Tasks

### 1. Authenticated Routing & Scope Hygiene

- [ ] Review `lib/homelab_web/router.ex` and ensure all LiveViews that expose host/docker actions live under the existing `:require_authenticated_user` pipeline and live_session.
- [ ] Pass `@current_scope` through every LiveView layout invocation (`<Layouts.app flash={@flash} current_scope={@current_scope}>`).
- [ ] Audit generated auth flows to confirm LAN/Tailscale-only exposure and no self-registration links remain.

### 2. Command Runtime & Supervision

- [ ] Stand up an execution supervisor tree dedicated to allowlisted commands (Docker pulls, compose up, restarts, host telemetry, reboot-required checks).
- [ ] Implement per-command modules (e.g., `Homelab.Commands.DockerPullAll`) that validate args, run shell/Docker interactions via `System.cmd/3` or `Req`, and emit structured events.
- [ ] Add single-flight locking/concurrency controls plus hard timeouts per run.
- [ ] Persist execution lifecycle records (start, completion, exit status, stdout/stderr summaries) to SQLite.

### 3. SQLite Persistence & Audit Log UX

- [ ] Design migrations for `operations`, `operation_events`, and `audit_logs` tables; capture indexes for querying recent history.
- [ ] Build Ecto contexts for recording runs, fetching history with pagination, and aggregating metrics (duration, success rate).
- [ ] Surface an audit-history LiveView with filters (command type, status, time window) and detail drilldowns.

### 4. LiveView Dashboard & Controls

- [ ] Create a primary dashboard LiveView showing container status, host disk/net telemetry, reboot-required flag, and quick actions.
- [ ] Use `<.input>` + Tailwind-based panels/forms for action modals (e.g., restart service, tail logs) with micro-interactions (hover/press states, optimistic loading widgets).
- [ ] Wire buttons/forms to `handle_event/3` callbacks that trigger command modules and stream updates back to the dashboard.

### 5. Docker Socket Integration & Service Directory

- [x] Mount `/var/run/docker.sock` into the Homelab container (document compose/service changes) so Req can talk to the local Docker Engine API without `System.cmd/3`.
- [x] Add a `Homelab.Docker` context (and behaviour-backed adapter) that issues authenticated HTTP requests via Req to endpoints like `GET /containers/json`, normalizes compose labels (`com.docker.compose.*`), and returns structs describing each service.
- [x] Extend `HomelabWeb.HomeLive` to call the Docker context during `mount/3`, store the results in a LiveView assign, and refresh them on load while handling socket errors gracefully.
- [x] Build function components for service cards, status badges, and empty/error states to keep the dashboard markup composable; include hover/press micro-interactions and unique DOM ids for future LiveView tests.
- [x] Write unit tests for the Docker context (parsing sample Docker JSON payloads) and LiveView tests that assert the service list renders under success/error scenarios by injecting a mock adapter.
- [ ] Add periodic refresh (timer or PubSub) so the service directory stays current without a full page reload.
- [x] Split the Docker panel into its own LiveView (`HomelabWeb.DockerLive.Services`) routed under the authenticated scope so the dashboard can embed it while keeping responsibilities isolated.
- [x] Extract host telemetry (clock + reboot status) into `HomelabWeb.HostLive.Signals` so the dashboard simply embeds the panel and we can reuse it elsewhere.

### 6. Log Streaming & Observability

- [ ] Implement supervised log-stream workers (`docker logs -f …`) that broadcast via PubSub, clamp stored lines, and escape payloads.
- [ ] Build LiveView components that subscribe to streams, show incremental output, and reflect command progress (pending/running/succeeded/failed badges).
- [ ] Add health indicators for compose services (status + last refresh timestamp) sourced from periodic command runs.

### 7. Developer Experience & Safety Net

- [ ] Define the `homelab-dev` Docker Compose stack plus helpers/scripts to start/stop it without touching production contexts.
- [ ] Add mix tasks or scripts for running representative command scenarios locally (e.g., `mix homelab.docker.pull_all`).
- [ ] Ensure `mix precommit` runs formatting, credo, test suites, and any dialyzer/spec checks.

### 8. Packaging & Deployment

- [ ] Configure releases to package Phoenix + execution supervisor into a single container that runs as a non-root user.
- [ ] Mount only the Docker socket and required volumes (SQLite DB, config, logs); document environment variables and secrets management.
- [ ] Document deployment steps, auth bootstrap, and rollback/runbook procedures in `docs/DEPLOYMENT.md` (or similar).

### 9. Future Backlog (Post-v1)

- [ ] Backup orchestration panels (visualize restic/systemd timers, trigger host scripts).
- [ ] Health trend charts (historical disk usage, compose restarts, probe latency).
- [ ] Drift detection comparing compose files vs running containers.
- [ ] Notification integrations (ntfy/email) driven by audit events.
- [ ] Host maintenance triggers that wrap existing systemd units (still allowlisted, no arbitrary commands).

## Next Steps

1. Socialize this plan, confirm priorities, and time-box each workstream.
2. Start with Workstreams 1–3 to establish the secure foundation (routing, command modules, persistence).
3. Layer UI/UX and streaming pieces once backend contracts are in place, then finish with deployment hardening.
