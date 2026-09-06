# Security Policy

## What this repository is

Docker Compose definitions for services running on a private homelab host.
Nothing here is published or distributed: no images are built, and the stacks
run on one machine behind a Cloudflare tunnel. There is no supported release
to report a vulnerability against.

## Reporting

Report privately via GitHub's
[security advisories](https://github.com/mainman94/docker-stack/security/advisories/new).
Please do not open a public issue for anything exploitable.

The interesting cases here are a **secret committed by mistake** or a compose
file that exposes a service it should not — a port published to `0.0.0.0`, a
missing auth layer in front of a stack. Both are real; both are worth a
private report rather than an issue.

## What is already covered

- **Every image is pinned by digest** (`image: name:tag@sha256:…`), so a
  repointed upstream tag cannot change what runs. Renovate updates the digests.
- **`gitleaks` runs as a pre-commit hook and in CI.** Real `.env` and
  `backup.env` files live on the deploy host and are never committed; the
  repository carries only `*.env.example` with placeholders.
- **A weekly trivy sweep** (`.github/workflows/scan.yml`) scans every
  referenced image and writes a per-image table to the run summary. It is
  advisory: these are other people's images, and a new upstream CVE is not
  something a commit here can fix.

## Vulnerabilities in the services themselves

Report those upstream — Jellyfin, Paperless-ngx, Vaultwarden and the rest each
have their own process. Report here only what this repository adds: the
compose files, the backup wiring, and the scripts.
