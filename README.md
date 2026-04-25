# dockerer-stack

Services live in separate Compose stacks under `eggenberg-services/`.

Central backups live in `infrastructure/volume-backup/` and are intended to be deployed as their own Dockhand stack on TrueNAS.
Each stack writes to its own host folder under `/mnt/default_pool/dockge/back/<stack>/`.

When adding a new application stack:
- give every named volume an explicit `name:`
- add `docker-volume-backup.stop-during-backup=true` to services that should be paused during backups
- mount the stack's named volumes or bind directories into `infrastructure/volume-backup/docker-compose.yaml`
- add a dedicated backup service there that writes to `/mnt/default_pool/dockge/back/<stack>/`
