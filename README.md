# dockerer-stack

Services live in separate Compose stacks under `eggenberg-services/`.

Central backups live in `infrastructure/volume-backup/` and are intended to be deployed as their own Dockhand stack on TrueNAS.
Each stack writes to its own host folder under `${BACKUP_ROOT}/<stack>/`.
`BACKUP_ROOT` and external Docker volume names are resolved by Compose from `infrastructure/volume-backup/.env`, while backup timing and retention live in `infrastructure/volume-backup/backup.env`.
Before deploying backup changes, run `infrastructure/volume-backup/check-backup-paths.sh` to verify that all `/backup/...` bind-mount sources exist. Empty source directories are reported as warnings.

When adding a new application stack:
- add `docker-volume-backup.stop-during-backup=true` to services that should be paused during backups
- mount the stack's named volumes or bind directories into `infrastructure/volume-backup/docker-compose.yaml`
- point external volume names in `infrastructure/volume-backup/.env` at the real Docker volume names on the host
- add a dedicated backup service there that writes to `${BACKUP_ROOT}/<stack>/`
- define an explicit default network named `<stack>_network`, replacing hyphens with underscores
