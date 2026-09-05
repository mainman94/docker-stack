## What

<!-- One or two sentences. -->

## Why

<!-- The problem this solves. Link the issue if there is one. -->

## Checklist

- [ ] `make check` passes (hooks, `docker compose config` per stack, conventions)
- [ ] New stack: has its own `.env.example`, a default network named
      `<stack>_network`, and a backup service in
      `infrastructure/volume-backup/` if it holds persistent data
- [ ] Backup wiring touched? `make backup-check` run **on the deploy host**,
      where the real bind-mount sources exist
- [ ] No real `.env`, `backup.env` or credential in the diff — only
      `*.env.example` with placeholders
