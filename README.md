# docker-stack

Services live in separate Compose stacks under `eggenberg-services/`.

## Services

| Stack | Description | Port |
|---|---|---|
| adguard-home | DNS ad-blocker | 30053 / 30054 |
| audiobookshelf | Audiobook & podcast server | 30067 |
| authelia | SSO / 2FA auth portal | 30091 |
| bambuddy | Bambu Lab printer companion | 30669 |
| firefly-iii | Personal finance manager | 30666 |
| gitea | Self-hosted Git service | 30056 |
| home-assistant | Home automation | 30123 |
| jellyfin | Media server | 30013 |
| jellystat | Jellyfin analytics | 30176 |
| navidrome | Music streaming server | 30043 |
| opencloud | Cloud file storage | 30080 |
| paperless-ngx | Document management | 30070 |
| pocket-id | OIDC identity provider | 30411 |
| radarr | Movie collection manager | 30025 |
| sabnzbd | Usenet downloader | 30670 |
| seerr | Media request manager | 30671 |
| sonarr | TV series collection manager | 30113 |
| swiparr | Jellyfin Tinder-style UI | 4321 |
| tailscale | VPN mesh | — |
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
