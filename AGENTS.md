# AGENTS

Docker Compose stacks for the eggenberg host. One directory per application
under `eggenberg-services/`, plus a central backup stack in
`infrastructure/volume-backup/`. There is no CI deploy — stacks are brought up
on the host itself, so a mistake in a compose file is only caught by the
checks in this repo.

## Local workflow

| Command                  | What it does                                              |
| ------------------------ | --------------------------------------------------------- |
| `make help`              | List every target                                         |
| `make tools`             | Install the pinned toolchain from `mise.toml`             |
| `make hooks`             | Install the git pre-commit hook (do this once)            |
| `make check`             | Everything a change must pass: lint + validate + conventions |
| `make validate`          | `docker compose config` every stack                       |
| `make conventions`       | Network naming and `.env.example` coverage                |
| `make lint`              | All pre-commit hooks over the whole tree                  |
| `make fmt`               | Reformat YAML and shell in place                          |
| `make backup-check`      | Verify backup bind-mount sources exist (deploy host only) |
| `make up STACK=jellyfin` | Start one stack                                           |
| `make scan`              | CVE sweep across every referenced image (advisory)        |
| `make images`            | List every image the stacks reference                     |

`.devcontainer/` gives you Docker and, through mise, everything else.

**Tool versions live in `mise.toml` and nowhere else.** python, pre-commit,
trivy, jq, actionlint and shellcheck are pinned there; the dev container's
post-create runs `mise install`, and CI installs from the same file with
`jdx/mise-action`. trivy in particular used to arrive three different ways —
an apt repo in the dev container, `curl … | sudo sh` in the scan workflow, and
whatever was on PATH locally. Bump the version in `mise.toml` and all three
move together; Renovate opens the PR.

## Automated checks

`.pre-commit-config.yaml` runs on every commit. Two hooks are repo-specific:

- **`compose-config`** — `docker compose config` per stack. It validates in a
  scratch copy holding only the compose file and its env files, materialising
  `<name>.example` as `<name>`, because the real `.env` / `backup.env` are
  host-only and never committed. Nothing is written into the worktree.
- **`stack-conventions`** — the default network is named `<stack>_network`,
  and every mandatory `${VAR}` has a key in that stack's `.env.example`.
  `${VAR:-default}` is treated as deliberately optional and is not required to
  appear. `paperless-ngx` and `pocket-id` are grandfathered on the network
  rule: renaming a live network restarts everything attached to it.

Two more hooks run over `.github/workflows/`: **`actionlint`** (workflow
schema, expression syntax, and the shell inside `run:` blocks — it uses the
pinned shellcheck) and **`zizmor`** (CI/CD security patterns: unpinned
actions, credentials left on disk by `actions/checkout`, template injection
through `${{ }}` in a run block).

Every action reference is pinned to a **commit SHA** with the tag in a
trailing comment. A moving tag can be repointed at new code without the pin
changing; Renovate keeps the digests current
(`helpers:pinGitHubActionDigests`). Do not "tidy" a pin back to `@v7`.

Skipping a hook needs a reason in the commit message. Do not add `--no-verify`
to a script.

What the hooks deliberately do **not** cover, because it needs the deploy host:

- Whether a bind-mount source actually exists — that is `make backup-check`.
- Whether an image tag resolves, or a container starts.

## Scanning

There is no CI deploy here, so CI is where the checks get a second run and
where the CVE picture comes from.

- **`.github/workflows/ci.yml`** runs every pre-commit hook on each PR. The
  runner has a Docker daemon, so `compose-config` really validates there.
- **`.github/workflows/scan.yml`** sweeps every image the stacks reference —
  47 of them — with trivy, weekly and on demand, and writes a per-image table
  to the run summary. `make scan` runs the same script locally, with the same
  trivy: both take it from `mise.toml`.

The sweep is **advisory on purpose**. These are other people's images; a new
upstream CVE is not something a commit here can fix, and a red build nobody
can clear is a build people stop reading. It uses `--ignore-unfixed` for the
same reason — an unfixed CVE is not actionable, and burying the fixable ones
under them is how a report stops being read. `make scan-strict` exits non-zero
on fixable CRITICALs if you ever want a gate.

Renovate already keeps the digest pins moving, so the usual fix for a finding
is to let it bump the image, not to hand-edit a tag.

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
- Run `make backup-check` before deploying backup changes to catch missing bind-mount sources.

## Secrets

Real `.env` files, and `infrastructure/volume-backup/backup.env`, are host-only
and gitignored. Only `*.env.example` is committed, and it holds placeholders —
never a real credential. `gitleaks` and `detect-private-key` run on every
commit, but they are a backstop, not the rule.
