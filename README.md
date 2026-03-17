# synology-borg-server

**[🇩🇪 Deutsche Version](README.de.md)**

Lightweight BorgBackup server running in Docker with SSH key-based authentication and per-client path restrictions.

Motivation: Synology does not allow interactive shell login for non-admin users, and those users cannot use the package-installed Borg as a Borg server. This container helps provide a dedicated Borg server on a Synology NAS.

## What this project does

- Runs `sshd` and `borgbackup` in an Alpine-based container.
- Creates a dedicated backup user from environment variables (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Loads authorized client public keys from a mounted `authorized_keys` file.
- Persists SSH host keys to keep the SSH fingerprint stable.
- Stores all Borg repositories under `/var/backup/borg` (mounted to your NAS storage).

## Repository structure

- `docker-compose.yml` – service configuration and host volume mounts.
- `context/Dockerfile` – container image definition.
- `context/docker-entrypoint.sh` – runtime user + sshd setup.
- `.env.example` – single-environment template.
- `.env.prod.example` – production template.
- `.env.test.example` – test template.
- `context/authorized_keys.example` – template with restricted key entries.

## Prerequisites

- Docker Engine with Compose support (`docker compose ...`).
- Host directories for:
  - SSH host keys
  - `authorized_keys` file
  - Borg repositories
- A dedicated non-admin user on your NAS/server.

## First-time setup (single environment)

1. Copy environment template:

   ```bash
   cp .env.example .env
   ```

2. Adjust `.env` values:
   - `TZ`
   - `SSH_HOST_PORT`
   - `SSH_CONFIG_DIR`
   - `AUTHORIZED_KEYS_FILE`
   - `BORG_REPOS_DIR`
   - `BORG_USER`, `BORG_UID`, `BORG_GID`

3. Create host paths and permissions:

   ```bash
   mkdir -p <SSH_CONFIG_DIR>
   mkdir -p <BORG_REPOS_DIR>
   touch <AUTHORIZED_KEYS_FILE>

   chown -R <BORG_UID>:<BORG_GID> <BORG_REPOS_DIR>
   chown <BORG_UID>:<BORG_GID> <AUTHORIZED_KEYS_FILE>

   chmod 750 <BORG_REPOS_DIR>
   chmod 640 <AUTHORIZED_KEYS_FILE>
   ```

4. Edit `authorized_keys` on the host:
   - Use `context/authorized_keys.example` as reference.
   - Add one line per client key with `--restrict-to-path`.

## Recommended: isolated prod + test stacks

Use two independent environment files and different Compose project names.

1. Create local env files:

   ```bash
   cp .env.prod.example .env.prod
   cp .env.test.example .env.test
   ```

2. Adjust values in each file:
   - Different `SSH_HOST_PORT` (for example: prod `2222`, test `2223`)
   - Different host paths (for example: `/volume1/borg-backups-prod/...` vs `/volume1/borg-backups-test/...`)
   - Different users/UIDs if possible (`borgprod` / `borgtest`)

3. Start both stacks:

   ```bash
   docker compose --env-file .env.prod -p borg-prod up -d --build
   docker compose --env-file .env.test -p borg-test up -d --build
   ```

4. Follow logs:

   ```bash
   docker compose --env-file .env.prod -p borg-prod logs -f synology-borg-server
   docker compose --env-file .env.test -p borg-test logs -f synology-borg-server
   ```

5. Stop stacks:

   ```bash
   docker compose --env-file .env.prod -p borg-prod down
   docker compose --env-file .env.test -p borg-test down
   ```

This gives strong separation for keys, repos, host fingerprints, and operational changes.

## Start / stop (single environment)

Start (build + run):

```bash
docker compose up -d --build
```

Check logs:

```bash
docker compose logs -f synology-borg-server
```

Stop:

```bash
docker compose down
```

## Client repository URL examples

Recommended: keep repository URL without explicit port and define SSH details via `BORG_RSH`.

```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

Example repository URLs:

- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-1`
- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-2`

## Notes

- SSH password login is disabled; only public-key authentication is allowed.
- Keep SSH host-key directories persistent to avoid fingerprint changes.
- `sshd` runs as root inside the container by design.
- Runtime hardening is enabled (`no-new-privileges`, dropped capabilities with minimal allowlist, `tmpfs` for `/run` and `/tmp`).
- `.env`, `.env.prod`, and `.env.test` should remain local and untracked.
