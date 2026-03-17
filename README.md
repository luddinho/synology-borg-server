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

   Check logs:

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

   Stop:


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
<details>
<summary>Example output</summary>

```text
[+] Building 23.3s (9/9) FINISHED
 => [synology-borg-server internal] load build definition from Dockerfile   2.7s
 => => transferring dockerfile: 327B                                      0.0s
 => [synology-borg-server internal] load .dockerignore                    2.5s
 => => transferring context: 2B                                           0.0s
 => [synology-borg-server internal] load metadata for docker.io/library/alpine:3.20   3.2s
 => [synology-borg-server 1/4] FROM docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805   4.5s
 => => resolve docker.io/library/alpine:3.20@sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805   1.1s
 => => sha256:a4f4213abb84c497377b8544c81b3564f313746700372ec4fe84653e4fb03805 9.22kB / 9.22kB   0.0s
 => => sha256:b0cb30c51c47cdfde647364301758b14c335dea2fddc9490d4f007d67ecb2538 1.02kB / 1.02kB   0.0s
 => => sha256:cc9071bd161080c1a543f3023b7d0db905b497e6ae757fe078227803bc7e4dc8 611B / 611B       0.0s
 => => sha256:76eb174b37c3e263a212412822299b58d4098a7f96715f18c7eb6932c98b7efd 3.63MB / 3.63MB   0.8s
 => => extracting sha256:76eb174b37c3e263a212412822299b58d4098a7f96715f18c7eb6932c98b7efd        0.5s
 => [synology-borg-server internal] load build context                    1.2s
 => => transferring context: 1.45kB                                      0.0s
 => [synology-borg-server 2/4] RUN apk add --no-cache     openssh-server     borgbackup     tzdata   5.5s
 => [synology-borg-server 3/4] COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh   1.6s
 => [synology-borg-server 4/4] RUN chmod +x /usr/local/bin/docker-entrypoint.sh   1.5s
 => [synology-borg-server] exporting to image                            2.9s
 => => exporting layers                                                  2.8s
 => => writing image sha256:d72b58bf9ca166207f14dd0d93e1fea4f44daf68c78dc6fb3548fee58a4f00b1      0.0s
 => => naming to docker.io/library/synology-borg-server:local            0.2s
[+] Running 2/2
 ✔ Network synology-borg-server_default  Created   0.5s
 ✔ Container synology-borg-server        Started   1.8s
```
</details>

</details>

Check logs:

```bash
docker compose logs -f synology-borg-server
```
<details>
<summary>Example output</summary>

```text
synology-borg-server  | ssh-keygen: generating new host keys: RSA ECDSA ED25519
synology-borg-server  | Server listening on 0.0.0.0 port 22.
synology-borg-server  | Server listening on :: port 22.
```
</details>

</details>

Stop:

 Check logs:
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
- `sshd` runs as root inside the container by design; the setup applies hardening via `no-new-privileges`, dropped Linux capabilities (`cap_drop: [ALL]` with a minimal `cap_add` allowlist), and `tmpfs` for `/run` and `/tmp`.
- To find UID/GID on the NAS:

  ```bash
   id <BORG_USER>
  ```

- `.env` is ignored by git; keep local secrets/config there.
