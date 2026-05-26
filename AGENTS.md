# AGENTS

## Compose stack conventions

- Each application stack lives in its own directory under `eggenberg-services/<stack>/`.
- Persistent bind-mounted data should live under `./<service-name>/...` relative to that stack's `docker-compose.yaml`.
- Prefer bind mounts under the stack directory over named Docker volumes for app data, unless there is a concrete reason not to.
- Keep media or other large shared datasets as explicit absolute host mounts when they are intentionally shared outside the stack.
- Add a stack-local `.env.example` when a compose file uses variable interpolation.
- Compose variables should be consumed via `${VAR_NAME}` syntax in the compose file.
- If a value must exist inside the container, explicitly pass it via the service `environment:` section; compose interpolation alone does not inject variables into the container.
- When validating a variable-driven compose file from outside the stack directory, pass `--env-file <stack>/.env.example` or `--env-file <stack>/.env`; service-level `env_file` entries do not satisfy compose interpolation on their own.
- Each stack should define an explicit default network named `<stack>_network`, replacing hyphens in stack directory names with underscores.

## Backup conventions

- Central backups are defined in `infrastructure/volume-backup/docker-compose.yaml`.
- Services whose data should be quiesced during backups must set the label `docker-volume-backup.stop-during-backup=true`.
- Every new stack with persistent data should get a dedicated backup service in the central backup compose file.
- Backup services should mount the same persistent bind directories or external volumes as read-only under `/backup/...`.
- Each backup service writes archives to `${BACKUP_ROOT}/<stack>/`.
- If a stack uses external named Docker volumes, the real host volume names must be documented in `infrastructure/volume-backup/.env` and `.env.example`.
- Re-creatable caches may still live under `./<service-name>/...` for consistency, but they should be excluded from backups unless there is a specific restore need.
- Run `infrastructure/volume-backup/check-backup-paths.sh` before deploying backup changes to catch missing bind-mount sources.
