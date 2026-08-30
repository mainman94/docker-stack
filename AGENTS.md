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

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
