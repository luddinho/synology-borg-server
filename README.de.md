# synology-borg-server

**[🇬🇧 English Version](README.md)**

Einfacher BorgBackup-Server in Docker mit SSH-Schlüssel-Authentifizierung und pro Client eingeschränkten Repository-Pfaden.

## Motivation
Synology DSM erlaubt für Nicht-Admin-Benutzer keinen interaktiven Shell-Login, und diese Benutzer können das paketinstallierte Borg nicht als Borg-Server verwenden. Dieser Container hilft dabei, auf einer Synology NAS einen dedizierten Borg-Server bereitzustellen.

## Was dieses Projekt bewirkt

- Startet `sshd` und `borgbackup` in einem Alpine-basierten Container.
- Legt einen dedizierten Backup-Benutzer über Umgebungsvariablen an (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Lädt erlaubte öffentliche Schlüssel aus einer gemounteten `authorized_keys`-Datei.
- Speichert SSH-Host-Keys persistent, damit der SSH-Fingerprint stabil bleibt.
- Speichert alle Borg-Repositories unter `/var/backup/borg`.

## Über Alpine Linux

Dieses Projekt verwendet Alpine Linux als Basis-Image für den Container. Alpine Linux ist eine leichtgewichtige, sicherheitsorientierte Linux-Distribution, die auf Einfachheit und Effizienz ausgelegt ist. Sie wird häufig in Docker-Umgebungen eingesetzt, weil:

- Das Basis-Image ist extrem klein (unter 6MB), was Builds beschleunigt und die Angriffsfläche reduziert.
- Alpine verwendet musl libc und busybox für Minimalismus und Performance.
- Paketmanagement erfolgt mit `apk`, das schnell und einfach zu bedienen ist.
- Entwickelt für den Einsatz in Containern, Microservices und Cloud-Umgebungen.
- Sicherheitsfeatures: minimale Privilegien, gehärtete Kernel-Optionen, reproduzierbare Builds.

Wie es in Docker funktioniert:
- Das offizielle Alpine-Image bietet ein minimales Root-Dateisystem.
- Es werden nur die benötigten Pakete installiert (z.B. `openssh-server`, `borgbackup`, `tzdata`) mit `apk add`.
- Der Container startet schnell, benötigt wenig Speicher und ist einfach aktuell zu halten.

Alpine eignet sich ideal für Szenarien, in denen eine sichere, schnelle und minimale Umgebung für Anwendungen benötigt wird.

> **Aktuelle Version:** Dieses Projekt verwendet aktuell `alpine:3.23`. Siehe `context/Dockerfile` zum Prüfen oder Aktualisieren der Version. Verfügbare Releases: [hub.docker.com/_/alpine](https://hub.docker.com/_/alpine/tags)

## Repository-Struktur

```
synology-borg-server/
├── docker-compose.yml                 – Service-Konfiguration und Host-Volume-Mounts.
├── .env.example                       – Vorlage für Single-Environment.
├── .env.prod.example                  – Vorlage für Produktion.
├── .env.test.example                  – Vorlage für Test.
├── authorized_keys.example            – Vorlage mit eingeschränkten Key-Einträgen.
├── context/
│   ├── Dockerfile                     – Container-Image-Definition.
│   └── docker-entrypoint.sh           – Laufzeit-Setup für User + sshd.
├── README.md                          – englische Version.
├── README.de.md                       – diese Datei (Deutsch).
└── LICENSE                            – Projektlizenz.
```

## Voraussetzungen

- Docker Engine mit Compose-Unterstützung (`docker compose ...`).
- Host-Verzeichnisse für:
  - SSH-Host-Keys
  - `authorized_keys`-Datei
  - Borg-Repositories
- Ein dedizierter Nicht-Admin-Benutzer auf NAS/Server.

## Kompatibilität

Dieses Projekt ist **nicht auf Synology NAS beschränkt**. Es kann auf jedem Linux-System verwendet werden, das die in diesem README genannten Voraussetzungen erfüllt und Docker Engine mit Compose-Unterstützung bereitstellt.

Dieser Container funktioniert auf **jedem Synology NAS-Modell, das Docker unterstützt** (Container Manager), unabhängig von der CPU-Architektur. Da das Image direkt auf dem NAS zur Laufzeit gebaut wird (`docker compose up --build`), verwendet Docker automatisch die native Architektur des Hosts — `x86_64`, `aarch64` oder `armv7`.

Das Alpine-Basis-Image und seine Pakete (`openssh`, `borgbackup`) sind für alle diese Architekturen verfügbar, sodass kein vorgefertigtes Image oder Cross-Compilation erforderlich ist.

> **Hinweis:** Docker (Container Manager) selbst setzt eine Mindest-DSM-Version und ein unterstütztes Modell voraus. Wenn Docker auf deinem NAS läuft, funktioniert dieser Container.

## NAS-Verzeichnisstruktur

Basierend auf den Umgebungsvariablen in `.env` (oder `.env.prod`/`.env.test`) hat dein Synology NAS eine Struktur wie folgt:

```
/volume1/borg-backups/                         # oder borg-backups-prod, borg-backups-test, etc.
├── config/
│   ├── ssh/                                   # SSH_CONFIG_DIR — persistent SSH-Host-Keys
│   │   ├── ssh_host_rsa_key
│   │   ├── ssh_host_rsa_key.pub
│   │   ├── ssh_host_ed25519_key
│   │   └── ssh_host_ed25519_key.pub
│   └── authorized_keys                        # AUTHORIZED_KEYS_FILE — öffentliche Schlüssel von Clients
└── repos/                                     # BORG_REPOS_DIR — alle Borg-Repositories
    ├── client-host-1/                         # Repository für client-host-1
    ├── client-host-2/                         # Repository für client-host-2
    └── .../
```

**Wichtige Punkte:**
- Jedes Verzeichnis und jede Datei wird vom Backup-Benutzer (definiert durch `BORG_UID:BORG_GID`) besessen.
- Berechtigungen sind auf Zugriff beschränkt (750 für Verzeichnisse, 600 für `authorized_keys`).
- SSH-Host-Keys sind persistent, damit sich der Fingerprint über Container-Neustarts nicht ändert.
- Jedes Client-Repository ist isoliert und Zugriff wird über `authorized_keys` kontrolliert.


## Start und Stopp

Wie du den BorgBackup-Server einrichtest, startest und stoppst. Wähle die passende Variante für dein Setup.

### Ersteinrichtung (Single-Environment)

Führe diese Schritte aus, bevor du den Server das erste Mal startest:

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
   chmod 600 <AUTHORIZED_KEYS_FILE>
   ```

4. `authorized_keys` auf dem Host bearbeiten:
   - `authorized_keys.example` als Vorlage verwenden.
   - Pro Client-Key eine Zeile mit `--restrict-to-path` ergänzen.

---

### Single-Environment-Variante

Diese Variante eignet sich am besten für einfache Setups, Heimanwender oder wenn du nur eine einzige BorgBackup-Server-Instanz benötigst. Alle Konfigurationen, Schlüssel und Repositories werden gemeinsam verwaltet. Nutze dies, wenn du keine strikte Trennung zwischen Produktion und Test brauchst.

Starten (Build + Run):

```bash
docker compose up -d --build
```

Logs anzeigen:

```bash
docker compose logs -f sshd
```

Stoppen:

```bash
docker compose down
```

### Empfohlen: Isolierte Prod- und Test-Stacks

Diese Variante ist ideal für fortgeschrittene Setups, produktive Umgebungen oder wenn du Produktions- und Testdaten, SSH-Schlüssel und Logs strikt trennen möchtest. Durch getrennte Environment-Dateien und Compose-Projektnamen kannst du mehrere unabhängige BorgBackup-Server-Instanzen auf demselben Host betreiben, ohne versehentliche Überschneidungen bei Daten oder Schlüsseln. Sehr empfehlenswert für alle, die sowohl Live- als auch Test-Backups verwalten oder für Teams mit unterschiedlichen Anforderungen.

Nutze zwei getrennte Environment-Dateien und unterschiedliche Compose-Projektnamen für eine saubere Trennung.

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
   docker compose --env-file .env.prod -p borg-prod logs -f sshd
   docker compose --env-file .env.test -p borg-test logs -f sshd
   ```

5. Stacks stoppen:

   ```bash
   docker compose --env-file .env.prod -p borg-prod down
   docker compose --env-file .env.test -p borg-test down
   ```

Das trennt Schlüssel, Repositories, SSH-Fingerprints und Änderungen sauber zwischen Prod und Test.

## Beispiel-Repository-URLs für Clients

Empfohlen: Repository-URL ohne expliziten Port nutzen und SSH-Details über `BORG_RSH` setzen.

**Bash/Zsh:**
```bash
export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
# Beispiel: Neues Repository initialisieren
borg init --encryption=repokey-blake2 ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/<DEIN_REPO_NAME>
```

**PowerShell:**

```powershell
$env:BORG_RSH = 'ssh -p <SSH_PORT> -i ~/.ssh/<IDENTITY_FILE> -o IdentitiesOnly=yes'
```

Beispiel-Repository-URLs:

- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-1`
- `ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-2`

## Beispiele
## Protokollierung

<details>
<summary>Erste Log-Einträge beim Container-Start</summary>

Dieses Beispiel zeigt die ersten Log-Einträge nach dem Build und Start des Containers. Der SSH-Server lauscht auf Verbindungen.

```
synology-borg-server-sshd-1  | Server listening on 0.0.0.0 port 22.
synology-borg-server-sshd-1  | Server listening on :: port 22.
```

</details>

<details>
<summary>Erfolgreiche Authentifizierung und Backup-Session-Logs</summary>

Dieses Beispiel zeigt Log-Ausgaben aus dem Container, nachdem ein Client Host sich verbindet, authentifiziert und ein Backup startet. Es demonstriert die SSH-Schlüssel-Authentifizierung und den ausgeführten Befehl `borg serve` für den Client.

```
synology-borg-server-sshd-1  | Connection from 192.168.0.1 port 37771 on 192.168.0.2 port 22 rdomain ""
synology-borg-server-sshd-1  | Accepted key ED25519 SHA256:**************************************** found at /home/borg/.ssh/authorized_keys:1
synology-borg-server-sshd-1  | Postponed publickey for borg from 192.168.0.1 port 37771 ssh2 [preauth]
synology-borg-server-sshd-1  | Accepted key ED25519 SHA256:**************************************** found at /home/borg/.ssh/authorized_keys:1
synology-borg-server-sshd-1  | Accepted publickey for borg from 192.168.0.1 port 37771 ssh2: ED25519 SHA256:****************************************
synology-borg-server-sshd-1  | User child is on pid 71
synology-borg-server-sshd-1  | Starting session: forced-command (key-option) 'borg serve --restrict-to-path /var/backup/borg/client-host-1' for borg from 192.168.0.1 port 37771 id 0
synology-borg-server-sshd-1  | Received disconnect from 192.168.0.1 port 37771:11: disconnected by user
synology-borg-server-sshd-1  | Disconnected from user borg 192.168.0.1 port 37771

synology-borg-server-sshd-1  | Connection from 192.168.0.1 port 37783 on 192.168.0.2 port 22 rdomain ""
synology-borg-server-sshd-1  | Accepted key ED25519 SHA256:**************************************** found at /home/borg/.ssh/authorized_keys:2
synology-borg-server-sshd-1  | Postponed publickey for borg from 192.168.0.1 port 37783 ssh2 [preauth]
synology-borg-server-sshd-1  | Accepted key ED25519 SHA256:**************************************** found at /home/borg/.ssh/authorized_keys:2
synology-borg-server-sshd-1  | Accepted publickey for borg from 192.168.0.1 port 37783 ssh2: ED25519 SHA256:****************************************
synology-borg-server-sshd-1  | User child is on pid 76
synology-borg-server-sshd-1  | Starting session: forced-command (key-option) 'borg serve --restrict-to-path /var/backup/borg/client-host-2' for borg from 192.168.0.1 port 37783 id 0
synology-borg-server-sshd-1  | Received disconnect from 192.168.0.1 port 37783:11: disconnected by user
synology-borg-server-sshd-1  | Disconnected from user borg 192.168.0.1 port 37783
```

</details>

## Hinweise

- SSH-Passwort-Login ist deaktiviert; nur Public-Key-Authentifizierung ist erlaubt.
- Halte die SSH-Host-Key-Verzeichnisse persistent, um Fingerprint-Änderungen zu vermeiden.
- `sshd` läuft im Container absichtlich als root.
- Laufzeit-Hardening ist aktiviert (`no-new-privileges`, reduzierte Capabilities mit Minimal-Whitelist, `tmpfs` für `/run` und `/tmp`).
- `.env`, `.env.prod` und `.env.test` sollten lokal und unverfolgt bleiben.
