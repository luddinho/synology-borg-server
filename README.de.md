# synology-borg-server

**[🇬🇧 English Version](README.md)**

Leichter BorgBackup-Server in Docker mit SSH-Schlüssel-Authentifizierung und pro Client eingeschränkten Repository-Pfaden.

Motivation: Synology erlaubt für Nicht-Admin-Benutzer keinen interaktiven Shell-Login, und diese Benutzer können das paketinstallierte Borg nicht als Borg-Server verwenden. Dieser Container hilft dabei, auf einer Synology NAS einen dedizierten Borg-Server bereitzustellen.

## Zweck dieses Projekts

- Startet `sshd` und `borgbackup` in einem Alpine-basierten Container.
- Legt einen dedizierten Backup-Benutzer über Umgebungsvariablen an (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Lädt erlaubte öffentliche Schlüssel aus einer gemounteten `authorized_keys`-Datei.
- Speichert SSH-Host-Keys persistent, damit der SSH-Fingerprint stabil bleibt.
- Speichert alle Borg-Repositories unter `/var/backup/borg` (auf deinen NAS-Speicher gemountet).

## Repository-Struktur

- `docker-compose.yml` – Service-Konfiguration und Host-Volume-Mounts.
- `context/Dockerfile` – Container-Image-Definition.
- `context/docker-entrypoint.sh` – Laufzeit-Setup für User + sshd.
- `.env.example` – Vorlage für Projekt-Umgebungsvariablen.
- `context/authorized_keys.example` – Vorlage mit eingeschränkten Key-Einträgen.

## Voraussetzungen

- Docker Engine mit Compose-Unterstützung (`docker compose ...`).
- Host-Verzeichnisse für:
  - SSH-Host-Keys (`/volume1/borg-backups/config/ssh`)
  - authorized_keys-Datei (`/volume1/borg-backups/config/authorized_keys`)
  - Backup-Repositories (`/volume1/borg-backups/repos`)
- Ein dedizierter Nicht-Admin-Benutzer auf dem NAS (z. B. `borg`).

## Ersteinrichtung

1. Umgebungs-Vorlage kopieren:

   ```bash
   cp .env.example .env
   ```

2. `.env` anpassen:
   - Host-Pfadwerte sind benutzer-/umgebungsspezifisch; die gezeigten Werte sind nur Beispiele und sollten angepasst werden.
   - Häufige Pfadmuster (nur Beispiele):
     - Synology: `/volume1/borg-backups/config/ssh`, `/volume1/borg-backups/config/authorized_keys`, `/volume1/borg-backups/repos`
     - Generisches Linux: `/srv/borg/config/ssh`, `/srv/borg/config/authorized_keys`, `/srv/borg/repos`
   - `TZ` = Zeitzone im Container
   - `SSH_HOST_PORT` = SSH-Port auf dem Host (auf Container-Port `22` gemappt)
   - `SSH_CONFIG_DIR` = Host-Pfad für persistente SSH-Host-Keys
   - `AUTHORIZED_KEYS_FILE` = Host-Pfad zur authorized_keys-Datei
   - `BORG_REPOS_DIR` = Host-Pfad für Borg-Repositories
   - `BORG_USER` = dedizierter Backup-Benutzer
   - `BORG_UID` / `BORG_GID` = IDs dieses Benutzers/der Gruppe auf dem Host

3. Dedizierten Backup-Benutzer auf NAS/Server anlegen:
   - Einen Nicht-Admin-Benutzer (z. B. `borg`) über NAS-Oberfläche oder CLI erstellen.
   - Dessen IDs auf dem Host auslesen und in `.env` als `BORG_UID` und `BORG_GID` eintragen.

   ```bash
   id <BORG_USER>
   ```

   Beispiel:

   ```bash
   id borg
   ```

4. Host-Pfade anlegen und Berechtigungen für die Backup-User-IDs setzen:
   - Pfade anpassen, falls in `.env` andere Werte verwendet werden.
   - Zur generischen Nutzung Platzhalter verwenden (`<BORG_UID>:<BORG_GID>`).

   ```bash
   mkdir -p <SSH_CONFIG_DIR>
   mkdir -p <BORG_REPOS_DIR>
   touch <AUTHORIZED_KEYS_FILE>

   chown -R <BORG_UID>:<BORG_GID> <BORG_REPOS_DIR>
   chown <BORG_UID>:<BORG_GID> <AUTHORIZED_KEYS_FILE>

   chmod 750 <BORG_REPOS_DIR>
   chmod 640 <AUTHORIZED_KEYS_FILE>
   ```

   - Beispiel mit konkreten Werten:

   ```bash
   chown -R 1070:100 /volume1/borg-backups/repos
   chown 1070:100 /volume1/borg-backups/config/authorized_keys
   ```

5. `authorized_keys` auf dem Host bearbeiten:
   - Pfad: `<AUTHORIZED_KEYS_FILE>` (aus `.env`)
   - `context/authorized_keys.example` als Vorlage verwenden.
   - Pro Client-Key eine Zeile mit `--restrict-to-path` auf den eigenen Repo-Pfad.

## Start / Stopp

Starten (Build + Run):

```bash
docker compose up -d --build
```
<details>
<summary>Beispielausgabe</summary>

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

Logs anzeigen:

</details>

Logs anzeigen:

```bash
docker compose logs -f synology-borg-server
```
<details>
<summary>Beispielausgabe</summary>

```text
synology-borg-server  | ssh-keygen: generating new host keys: RSA ECDSA ED25519
synology-borg-server  | Server listening on 0.0.0.0 port 22.
synology-borg-server  | Server listening on :: port 22.
```
</details>

Stoppen:

</details>

Stoppen:

```bash
docker compose down
```

## Beispiel-Repository-URLs für Clients

Empfohlen: Repository-URL ohne expliziten Port nutzen und die SSH-Details in `BORG_RSH` setzen.

```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

Hinweis: In PowerShell sind `$env:...`-Variablen standardmäßig nur für die aktuelle Sitzung gültig (für Persistenz im Profil setzen).

Beispiel (Standard-Host-Port `2222`):

```bash
export BORG_RSH='ssh -p 2222 -i ~/.ssh/id_ed25519_borg -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p 2222 -i ~/.ssh/id_ed25519_borg -o IdentitiesOnly=yes'
```

- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-1`
- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-2`

Beispiel mit Standard-Benutzer:

- `ssh://borg@<SYNOLOGY_IP>/var/backup/borg/client-host-1`
- `ssh://borg@<SYNOLOGY_IP>/var/backup/borg/client-host-2`

## Hinweise

- SSH-Passwort-Login ist deaktiviert; nur Public-Key-Authentifizierung ist erlaubt.
- `/volume1/borg-backups/config/ssh` muss persistent bleiben, damit sich Host-Keys nicht ändern.
- `sshd` läuft im Container aus technischen Gründen als root; zur Härtung werden `no-new-privileges`, reduzierte Linux-Capabilities (`cap_drop: [ALL]` mit minimaler `cap_add`-Allowlist) sowie `tmpfs` für `/run` und `/tmp` verwendet.
- UID/GID auf dem NAS herausfinden:

  ```bash
   id <BORG_USER>
  ```

- `.env` wird von git ignoriert; lokale Konfiguration dort ablegen.
