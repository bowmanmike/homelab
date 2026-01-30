# Tasks & TODOs

## Bugs

- [ ] Flash messages not appearing after compose update commands - `put_flash(:info, ...)` is called but no `#flash-info` element appears in DOM. Investigate LiveView flash handling.

## Features

- [ ] Add periodic refresh for Docker panel (currently only refreshes on mount and after commands)
- [ ] Add log streaming for compose commands (currently just captures output at completion)
- [ ] Audit logging for compose operations (persist to SQLite)
