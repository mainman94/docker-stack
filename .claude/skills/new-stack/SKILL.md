---
name: new-stack
description: Scaffold a new eggenberg-services Compose stack and wire its central backup service, following this repo's conventions. Use when adding a new self-hosted service.
disable-model-invocation: true
---

# new-stack

Scaffold a new stack under `eggenberg-services/<stack>/` and wire it into
`infrastructure/volume-backup/`, matching the 20 existing stacks.

## Inputs

Ask the user (or infer from their request) for:

- **stack** — directory name, hyphenated (e.g. `linkwarden`).
- **image** — pinned image tag (never `latest`).
- **container port** — internal app port.
- **web port** — host port in the `30xxx` band (check README table for a free one).
- whether it needs a **database** (postgres) or other sidecars.
- persistent **data paths** and any shared absolute media mounts.

`<stack_us>` below = stack name with hyphens replaced by underscores.
`<STACK>` = stack name uppercased, hyphens→underscores.

## Steps

1. **Copy the template** `templates/docker-compose.yaml` → `eggenberg-services/<stack>/docker-compose.yaml`
   and `templates/env.example` → `eggenberg-services/<stack>/.env.example`.
   Replace every `SERVICE` / `<stack>` / `<STACK>` / `<stack_us>` placeholder.
   Keep: `user: 568:568`, `TZ=Europe/Vienna`, a healthcheck, `cpus` + `mem_limit`,
   and `network: <stack_us>_network`.

2. **Add the backup label** `docker-volume-backup.stop-during-backup=<stack>` to every
   service in the stack that holds persistent data.

3. **Add a backup service** to `infrastructure/volume-backup/docker-compose.yaml`
   (copy an existing `*_backup` block). Mount `${<STACK>_STACK_HOST_PATH}:/backup/<stack_us>_stack:ro`
   and archive to `${BACKUP_ROOT:-/mnt/default_pool/dockge/back}/<stack>`. Set
   `BACKUP_FILENAME`, `BACKUP_PRUNING_PREFIX`, `BACKUP_STOP_DURING_BACKUP_LABEL=<stack>`.

4. **Add the host path** `<STACK>_STACK_HOST_PATH=/mnt/default_pool/dockge/stacks/Production/<stack>`
   to `infrastructure/volume-backup/backup.env.example`.

5. **Update the README** service table (Stack | Description | Port).

6. **Verify:**
   - `docker compose --env-file eggenberg-services/<stack>/.env.example -f eggenberg-services/<stack>/docker-compose.yaml config -q`
   - `docker compose --env-file infrastructure/volume-backup/backup.env.example -f infrastructure/volume-backup/docker-compose.yaml config -q`

## Conventions (must hold)

- All values interpolated via `${VAR}`; `.env.example` covers **every** `${VAR}` used.
- Bind mounts under `./<stack>/...`; shared media as explicit absolute host paths.
- Default UID/GID `568`, TZ `Europe/Vienna`.
- Explicit `networks.default.name: <stack_us>_network`.
- Pin image tags. Add `# renovate:` comments only if the image needs a depName hint.
