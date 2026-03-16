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
- `.env.example` – template for project environment variables.
- `context/authorized_keys.example` – template with restricted key entries.

## Prerequisites

- Docker Engine with Compose support (`docker compose ...`).
- A host directory for:
  - SSH host keys (`/volume1/borg-backups/config/ssh`)
  - authorized keys file (`/volume1/borg-backups/config/authorized_keys`)
  - backup repositories (`/volume1/borg-backups/repos`)
- A dedicated non-admin user on your NAS (example: `borg`).

## First-time setup

1. Copy environment template:

   ```bash
   cp .env.example .env
   ```

2. Adjust `.env`:
   - Host path values are user-specific; the shown values are examples and should be customized.
   - Common path patterns (examples only):
     - Synology: `/volume1/borg-backups/config/ssh`, `/volume1/borg-backups/config/authorized_keys`, `/volume1/borg-backups/repos`
     - Generic Linux: `/srv/borg/config/ssh`, `/srv/borg/config/authorized_keys`, `/srv/borg/repos`
   - `TZ` = container time zone
   - `SSH_HOST_PORT` = SSH port exposed on the host (mapped to container port `22`)
   - `SSH_CONFIG_DIR` = host path for persistent SSH host keys
   - `AUTHORIZED_KEYS_FILE` = host path to authorized keys file
   - `BORG_REPOS_DIR` = host path where Borg repos are stored
   - `BORG_USER` = dedicated backup user
   - `BORG_UID` / `BORG_GID` = IDs of that user/group on the host

3. Create a dedicated backup user on the NAS/server:
   - Create a non-admin user (for example `borg`) via your NAS UI or CLI.
   - Read its IDs on the host and copy them into `.env` as `BORG_UID` and `BORG_GID`.

   ```bash
   id <BORG_USER>
   ```

   Example:

   ```bash
   id borg
   ```

4. Create host paths and assign permissions for the backup user IDs:
   - Replace paths if you use different values in `.env`.
   - Use placeholders (`<BORG_UID>:<BORG_GID>`) to stay generic.

   ```bash
   mkdir -p <SSH_CONFIG_DIR>
   mkdir -p <BORG_REPOS_DIR>
   touch <AUTHORIZED_KEYS_FILE>

   chown -R <BORG_UID>:<BORG_GID> <BORG_REPOS_DIR>
   chown <BORG_UID>:<BORG_GID> <AUTHORIZED_KEYS_FILE>

   chmod 750 <BORG_REPOS_DIR>
   chmod 640 <AUTHORIZED_KEYS_FILE>
   ```

   - Example with concrete values:

   ```bash
   chown -R 1070:100 /volume1/borg-backups/repos
   chown 1070:100 /volume1/borg-backups/config/authorized_keys
   ```

5. Edit `authorized_keys` on the host:
   - Path: `<AUTHORIZED_KEYS_FILE>` (from `.env`)
   - Use `context/authorized_keys.example` as reference.
   - Add one line per client key with `--restrict-to-path` for its own repo path.

## Start / stop

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

Recommended: keep the repository URL without an explicit port and define SSH details in `BORG_RSH`.

```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

Note: In PowerShell, `$env:...` variables are session-local by default (set them in your profile for persistence).

Example (default host port `2222`):

```bash
export BORG_RSH='ssh -p 2222 -i ~/.ssh/id_ed25519_borg -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p 2222 -i ~/.ssh/id_ed25519_borg -o IdentitiesOnly=yes'
```

- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-1`
- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-2`

Example with default user:

- `ssh://borg@<SYNOLOGY_IP>/var/backup/borg/client-host-1`
- `ssh://borg@<SYNOLOGY_IP>/var/backup/borg/client-host-2`

## Notes

- SSH password login is disabled; only public key auth is allowed.
- Keep `/volume1/borg-backups/config/ssh` persistent to avoid host key changes.
- To find UID/GID on the NAS:

  ```bash
   id <BORG_USER>
  ```

- `.env` is ignored by git; keep local secrets/config there.
