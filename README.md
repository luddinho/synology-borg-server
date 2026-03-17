# synology-borg-server

**[🇩🇪 Deutsche Version](README.de.md)**

Lightweight BorgBackup server running in Docker with SSH key-based authentication and per-client path restrictions.

## Motivation
Synology DSM does not allow interactive shell login for non-admin users, and those users cannot use the package-installed Borg as a Borg server. This container helps provide a dedicated Borg server on a Synology NAS.

## What this project does

- Runs `sshd` and `borgbackup` in an Alpine-based container.
- Creates a dedicated backup user from environment variables (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Loads authorized client public keys from a mounted `authorized_keys` file.
- Persists SSH host keys to keep the SSH fingerprint stable.
- Stores all Borg repositories under `/var/backup/borg` (mounted to your NAS storage).

## About Alpine Linux 3.20

This project uses Alpine Linux 3.20 as the base image for the container. Alpine Linux is a lightweight, security-focused Linux distribution designed for simplicity and efficiency. It is widely used in Docker environments because:

- The base image is extremely small (under 6MB), which speeds up builds and reduces attack surface.
- Alpine uses musl libc and busybox for minimalism and performance.
- Package management is handled by `apk`, which is fast and easy to use.
- Designed for running applications in containers, microservices, and cloud environments.
- Security features: minimal privileges, hardened kernel options, reproducible builds.

How it works in Docker:
- The official `alpine:3.20` image provides a minimal root filesystem.
- You install only the packages you need (e.g., `openssh-server`, `borgbackup`, `tzdata`) using `apk add`.
- The container starts quickly, uses little memory, and is easy to keep up-to-date.

Alpine is ideal for scenarios where you want a secure, fast, and minimal environment for your application.

## Repository structure

- `docker-compose.yml` – service configuration and host volume mounts.
- `context/Dockerfile` – container image definition.
- `context/docker-entrypoint.sh` – runtime user + sshd setup.
- `.env.example` – single-environment template.
- `.env.prod.example` – production template.
- `.env.test.example` – test template.
- `authorized_keys.example` – template with restricted key entries.

## Prerequisites

- Docker Engine with Compose support (`docker compose ...`).
- Host directories for:
  - SSH host keys
  - `authorized_keys` file
  - Borg repositories
- A dedicated non-admin user on your NAS/server.

## Compatibility

This container works on **any Synology NAS model that supports Docker** (Container Manager), regardless of CPU architecture. Because the image is built directly on the NAS at runtime (`docker compose up --build`), Docker automatically uses the host's native architecture — `x86_64`, `aarch64`, or `armv7`.

The Alpine base image and its packages (`openssh`, `borgbackup`) are available for all these architectures, so no pre-built image or cross-compilation is needed.

> **Note:** Docker (Container Manager) itself requires a minimum DSM version and a supported model. If Docker runs on your NAS, this container will work.


## Start and Stop

How to set up, start, and stop the BorgBackup server. Choose the approach that fits your setup.

### First-time Setup (Single Environment)

Follow these steps to prepare your environment before starting the server for the first time:

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
   - Use `authorized_keys.example` as reference.
   - Add one line per client key with `--restrict-to-path`.

---

### Single-Environment Approach

This approach is best suited for simple setups, home use, or when you only need a single BorgBackup server instance. All configuration, keys, and repositories are managed together. Use this if you do not need strict separation between production and test environments.

Start (build and run):

```bash
docker compose up -d --build
```

Check logs:

```bash
docker compose logs -f sshd
```

Stop:

```bash
docker compose down
```


### Recommended: Isolated Prod + Test Stacks

This approach is ideal for advanced setups, production environments, or when you want to keep production and test data, SSH keys, and logs strictly separated. By using separate environment files and Compose project names, you can run multiple independent BorgBackup server instances on the same host without risk of accidental data or key overlap. This setup is highly recommended for anyone managing both live and test backups, or for teams with different operational needs.

Use two independent environment files and different Compose project names for strong separation.

1. Create local environment files:

   ```bash
   cp .env.prod.example .env.prod
   cp .env.test.example .env.test
   ```

2. Adjust values in each file:
   - Different `SSH_HOST_PORT` (e.g., prod `2222`, test `2223`)
   - Different host paths (e.g., `/volume1/borg-backups-prod/...` vs `/volume1/borg-backups-test/...`)
   - Different users/UIDs if possible (`borgprod` / `borgtest`)

3. Start both stacks:

   ```bash
   docker compose --env-file .env.prod -p borg-prod up -d --build
   docker compose --env-file .env.test -p borg-test up -d --build
   ```

4. Follow logs:

   ```bash
   docker compose --env-file .env.prod -p borg-prod logs -f sshd
   docker compose --env-file .env.test -p borg-test logs -f sshd
   ```

5. Stop stacks:

   ```bash
   docker compose --env-file .env.prod -p borg-prod down
   docker compose --env-file .env.test -p borg-test down
   ```

This gives strong separation for keys, repos, host fingerprints, and operational changes.

## Client repository URL examples

Recommended: keep repository URL without explicit port and define SSH details via `BORG_RSH`.



**Bash/Zsh:**
```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
# Example: initialize a new repository
borg init --encryption=repokey-blake2 ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/<YOUR_REPO_NAME>
```

**PowerShell:**

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
