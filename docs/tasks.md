# Tasks & TODOs

## Bugs

- [ ] Flash messages not appearing after compose update commands - `put_flash(:info, ...)` is called but no `#flash-info` element appears in DOM. Investigate LiveView flash handling.

## Testing

- [ ] Add tests for `Homelab.Compose` module (update_service, pull_service, recreate_service)
- [ ] Add tests for `Homelab.Compose.Lock` (acquire/release, auto-release on crash, queuing)
- [ ] Add tests for `Homelab.Compose.Runner` (service name validation, timeout handling)

## Features

- [ ] Host reboot from UI — requires host access from inside container (D-Bus socket mount, SSH, or host agent). See architecture.md for security constraints.
- [ ] Add periodic refresh for Docker panel (currently only refreshes on mount and after commands)
- [ ] Add log streaming for compose commands (currently just captures output at completion)
- [ ] Audit logging for compose operations (persist to SQLite)
