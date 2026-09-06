# docker-stack

Services live in separate Compose stacks under `eggenberg-services/`, deployed
to TrueNAS through Dockhand. Central backups live in `infrastructure/`.

There is no build step and no application code here — the whole repository is
Compose files, `.env.example` files and the scripts that check them.

## Getting started

```bash
make tools    # install the pinned toolchain from mise.toml
make hooks    # install the git pre-commit hooks, once
make check    # what a PR needs: hooks + compose config + conventions
```

`make help` lists every target. Day to day: `make stacks` lists them,
`make config STACK=jellyfin` prints a stack's fully resolved Compose config,
and `make up|down|restart|pull|logs STACK=<name>` operate on one.

**Tool versions live in `mise.toml` and nowhere else**, and CI installs from the
same file — so a hook that passes locally passes in CI.

## Services

| Stack | Description | Port |
|---|---|---|
| adguard-home | DNS ad-blocker | 30053 / 30054 |
| audiobookshelf | Audiobook & podcast server | 30067 |
| bambuddy | Bambu Lab printer companion | 30669 |
| bazarr | Subtitle manager for Sonarr/Radarr | 30068 |
| dockhand | Docker compose stack manager (runs this repo's stacks) | 30328 |
| firefly-iii | Personal finance manager | 30666 |
| gitea | Self-hosted Git service | 30056 |
| home-assistant | Home automation | 30123 |
| jellyfin | Media server | 30013 |
| jellystat | Jellyfin analytics | 30176 |
| linkding | Bookmark manager | 30044 |
| navidrome | Music streaming server | 30043 |
| open-webui | LLM chat UI with LiteLLM model router | 30081 |
| openbao | Secrets manager (Vault fork) | 30020 |
| opencloud | Cloud file storage | 30080 |
| opengym | Self-hosted gym & workout tracker | 30781 |
| paperless-ngx | Document management | 30070 |
| pocket-id | OIDC identity provider | 30411 |
| radarr | Movie collection manager | 30025 |
| recyclarr | Sonarr/Radarr config sync (cron) | — |
| sabnzbd | Usenet downloader | 30670 |
| seerr | Media request manager | 30671 |
| sonarr | TV series collection manager | 30113 |
| swiparr | Jellyfin Tinder-style UI | 4321 |
| tailscale | VPN mesh | — |
| tfc-agent | HCP Terraform / app.terraform.io self-hosted agent | — |
| umami | Web analytics | 30060 |
| vaultwarden | Bitwarden-compatible password manager | 30032 |

## Backup

Central backups live in `infrastructure/volume-backup/` and are intended to be deployed as their own Dockhand stack on TrueNAS.
Each stack writes to its own host folder under `${BACKUP_ROOT}/<stack>/`.
`BACKUP_ROOT` and stack host paths are resolved by Compose from `infrastructure/volume-backup/.env`, while backup timing and retention live in `infrastructure/volume-backup/backup.env`.
The backup stack also runs an unhealthy-container restart watcher for containers labeled with `docker-volume-backup.stop-during-backup`; tune its polling interval with `UNHEALTHY_RESTART_INTERVAL_SECONDS`.
Before deploying backup changes, run `infrastructure/volume-backup/check-backup-paths.sh` to verify that all `/backup/...` bind-mount sources exist. Empty source directories are reported as warnings.

## Adding a new stack

- Create `eggenberg-services/<stack>/docker-compose.yaml` and `.env.example`
- Add `docker-volume-backup.stop-during-backup=<stack-name>` to services that should be paused during backups
- Add a dedicated `<stack>_backup` service to `infrastructure/volume-backup/docker-compose.yaml` that mounts the stack directory read-only under `/backup/<stack>_stack` and writes archives to `${BACKUP_ROOT}/<stack>/`
- Add `<STACK>_STACK_HOST_PATH` to `infrastructure/volume-backup/backup.env.example`
- Define an explicit default network named `<stack>_network`, replacing hyphens with underscores

## Checks

`make check` is the whole local gate, and it is what a pull request runs:

| Step | What it catches |
| --- | --- |
| `make lint` | yamlfmt, shellcheck/shfmt, gitleaks, and `actionlint` + `zizmor` over the workflows |
| `make validate` | `docker compose config` per stack — an interpolation or schema error before it reaches the host |
| `make conventions` | `scripts/check-stack-conventions.sh`: the `<stack>_network` naming rule and `.env.example` coverage for every variable a Compose file reads |

`.env.example` coverage is the one worth calling out: a variable referenced in a
Compose file but missing from `.env.example` deploys fine on the host that
already has it set and fails for everyone else. The check exists because that
happened.

One required check gates a merge: **`pre-commit`**. The image CVE sweep
(`scan.yml`) is deliberately not required — it is path-filtered and advisory,
and a required check that does not run on every pull request blocks the merge
for good. It runs weekly and answers "which of my services is currently
exposed"; a new upstream CVE in somebody else's image is not something a commit
here can fix. `make scan` runs the same sweep locally, `make scan-strict` fails
on fixable criticals.

## Agent tooling

`.claude/` is checked in: a `stack-consistency-reviewer` agent for diffs, a
`new-stack` skill that scaffolds all five pieces listed above from templates, a
`backup-preflight` skill, and two hooks — one refuses to edit a real `.env`
(they are gitignored, so the edit would be invisible), the other validates a
Compose file as soon as it is written. [`AGENTS.md`](AGENTS.md) is the detailed
guide.

## License and security

MIT ([`LICENSE`](LICENSE)). To report a vulnerability, see
[`SECURITY.md`](SECURITY.md) — please do not open a public issue for one.
