# synology-borg-server

**[🇬🇧 English Version](README.md)**

Leichter BorgBackup-Server in Docker mit SSH-Schlüssel-Authentifizierung und pro Client eingeschränkten Repository-Pfaden.

Motivation: Synology erlaubt für Nicht-Admin-Benutzer keinen interaktiven Shell-Login, und diese Benutzer können das paketinstallierte Borg nicht als Borg-Server verwenden. Dieser Container hilft dabei, auf einer Synology NAS einen dedizierten Borg-Server bereitzustellen.

## Zweck dieses Projekts

- Startet `sshd` und `borgbackup` in einem Alpine-basierten Container.
- Legt einen dedizierten Backup-Benutzer über Umgebungsvariablen an (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Lädt erlaubte öffentliche Schlüssel aus einer gemounteten `authorized_keys`-Datei.
- Speichert SSH-Host-Keys persistent, damit der SSH-Fingerprint stabil bleibt.
- Speichert alle Borg-Repositories unter `/var/backup/borg`.

## Repository-Struktur

- `docker-compose.yml` – Service-Konfiguration und Host-Volume-Mounts.
- `context/Dockerfile` – Container-Image-Definition.
- `context/docker-entrypoint.sh` – Laufzeit-Setup für User + sshd.
- `.env.example` – Vorlage für Single-Environment.
- `.env.prod.example` – Vorlage für Produktion.
- `.env.test.example` – Vorlage für Test.
- `context/authorized_keys.example` – Vorlage mit eingeschränkten Key-Einträgen.

## Voraussetzungen

- Docker Engine mit Compose-Unterstützung (`docker compose ...`).
- Host-Verzeichnisse für:
  - SSH-Host-Keys
  - `authorized_keys`-Datei
  - Borg-Repositories
- Ein dedizierter Nicht-Admin-Benutzer auf NAS/Server.

## Ersteinrichtung (Single-Environment)

1. Umgebungs-Vorlage kopieren:

   ```bash
   cp .env.example .env
   ```

2. `.env` anpassen:
   - `TZ`
   - `SSH_HOST_PORT`
   - `SSH_CONFIG_DIR`
   - `AUTHORIZED_KEYS_FILE`
   - `BORG_REPOS_DIR`
   - `BORG_USER`, `BORG_UID`, `BORG_GID`

3. Host-Pfade anlegen und Berechtigungen setzen:

   ```bash
   mkdir -p <SSH_CONFIG_DIR>
   mkdir -p <BORG_REPOS_DIR>
   touch <AUTHORIZED_KEYS_FILE>

   chown -R <BORG_UID>:<BORG_GID> <BORG_REPOS_DIR>
   chown <BORG_UID>:<BORG_GID> <AUTHORIZED_KEYS_FILE>

   chmod 750 <BORG_REPOS_DIR>
   chmod 640 <AUTHORIZED_KEYS_FILE>
   ```

4. `authorized_keys` auf dem Host bearbeiten:
   - `context/authorized_keys.example` als Vorlage verwenden.
   - Pro Client-Key eine Zeile mit `--restrict-to-path` ergänzen.

## Empfohlen: isolierte Prod- und Test-Stacks

Nutze zwei getrennte Environment-Dateien und unterschiedliche Compose-Projektnamen.

1. Lokale Environment-Dateien erstellen:

   ```bash
   cp .env.prod.example .env.prod
   cp .env.test.example .env.test
   ```

2. Werte pro Umgebung anpassen:
   - Unterschiedliche `SSH_HOST_PORT` (z. B. Prod `2222`, Test `2223`)
   - Unterschiedliche Host-Pfade (z. B. `/volume1/borg-backups-prod/...` vs `/volume1/borg-backups-test/...`)
   - Nach Möglichkeit unterschiedliche Benutzer/UIDs (`borgprod` / `borgtest`)

3. Beide Stacks starten:

   ```bash
   docker compose --env-file .env.prod -p borg-prod up -d --build
   docker compose --env-file .env.test -p borg-test up -d --build
   ```

4. Logs je Umgebung prüfen:

   ```bash
   docker compose --env-file .env.prod -p borg-prod logs -f synology-borg-server
   docker compose --env-file .env.test -p borg-test logs -f synology-borg-server
   ```

5. Stacks stoppen:

   ```bash
   docker compose --env-file .env.prod -p borg-prod down
   docker compose --env-file .env.test -p borg-test down
   ```

Das trennt Schlüssel, Repositories, SSH-Fingerprints und Änderungen sauber zwischen Prod und Test.

## Start / Stopp (Single-Environment)

Starten (Build + Run):

```bash
docker compose up -d --build
```

Logs anzeigen:

```bash
docker compose logs -f synology-borg-server
```

Stoppen:

```bash
docker compose down
```

## Beispiel-Repository-URLs für Clients

Empfohlen: Repository-URL ohne expliziten Port nutzen und SSH-Details über `BORG_RSH` setzen.

```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

PowerShell:

```powershell
$env:BORG_RSH = 'ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

Beispiel-Repository-URLs:

- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-1`
- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-2`

## Hinweise

- SSH-Passwort-Login ist deaktiviert; nur Public-Key-Authentifizierung ist erlaubt.
- SSH-Host-Key-Verzeichnisse müssen persistent bleiben, damit sich Fingerprints nicht ändern.
- `sshd` läuft im Container aus technischen Gründen als root.
- Runtime-Härtung ist aktiv (`no-new-privileges`, reduzierte Capabilities inkl. `SYS_CHROOT`, `tmpfs` für `/run` und `/tmp`).
- `.env`, `.env.prod` und `.env.test` sollten lokal bleiben und nicht committed werden.
