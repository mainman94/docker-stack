---
name: backup-preflight
description: Run the volume-backup path preflight before deploying backup changes. Use before touching infrastructure/volume-backup or after adding a stack's backup service.
---

# backup-preflight

Verify every `/backup/...` bind-mount source in the central backup stack exists,
before deploying. Wraps the repo's own `check-backup-paths.sh` (AGENTS.md requires
running it before backup changes).

## Run

```sh
sh infrastructure/volume-backup/check-backup-paths.sh infrastructure/volume-backup/backup.env.example
```

Pass the real `infrastructure/volume-backup/.env` instead when validating on the
deploy host (that file holds the true `*_STACK_HOST_PATH` values).

## Read the output

- `OK:`    source exists and is non-empty — good.
- `WARN:`  source exists but empty — preflight still passes; expected for a brand-new
  stack whose data dir isn't populated yet.
- `ERROR:` source missing or not a directory — preflight **fails** (exit 1). Fix the
  host path or create the directory before deploying.

## Common causes of ERROR

- Added a `*_backup` service but forgot the matching `<STACK>_STACK_HOST_PATH` in
  `backup.env` / `backup.env.example`.
- Stack dir not yet created at `${STACKS_ROOT}/<stack>`.
- Typo between the backup service's `${...}` var and the env key.
