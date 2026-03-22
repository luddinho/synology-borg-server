# synology-borg-server

<p align="center"><img src="logo.svg" width="200" alt="synology-borg-server Logo"/></p>

Sprache: 🇩🇪 Deutsch | [🇬🇧 English](README.md)

Einfacher BorgBackup-Server in Docker mit SSH-Schlüssel-Authentifizierung und pro Client eingeschränkten Repository-Pfaden.

## Motivation
Synology DSM erlaubt für Nicht-Admin-Benutzer keinen interaktiven Shell-Login, und diese Benutzer können das paketinstallierte Borg nicht als Borg-Server verwenden. Dieser Container hilft dabei, auf einer Synology NAS einen dedizierten Borg-Server bereitzustellen.

> **Hinweis:** Dieser Container ist nicht auf Synology NAS beschränkt. Er kann auf jedem NAS (z.B. UGREEN, QNAP, TerraMaster) oder Linux-Server mit Docker Engine verwendet werden. Siehe Abschnitt [Kompatibilität](#kompatibilität) für Details.

## Was dieses Projekt bewirkt

- Startet `sshd` und `borgbackup` in einem Alpine-basierten Container.
- Legt einen dedizierten Backup-Benutzer über Umgebungsvariablen an (`BORG_USER`, `BORG_UID`, `BORG_GID`).
- Lädt erlaubte öffentliche Schlüssel aus einer gemounteten `authorized_keys`-Datei.
- Speichert SSH-Host-Keys persistent, damit der SSH-Fingerprint stabil bleibt.
- Speichert alle Borg-Repositories unter `/var/backup/borg`.

## Vorteile dieses Projekts
Wenn der Borg-Server in einem Docker-Container läuft, der von einem Nicht-Admin-Benutzer mit aktiviertem restrict-Pfadschutz genutzt werden kann, ergeben sich folgende Vorteile:

1. **Erhöhte Sicherheit:**
   - Der Container läuft als Nicht-Root-Benutzer, wodurch das Risiko von Rechteausweitungen und Sicherheitslücken minimiert wird.
   - Die Authentifizierung per SSH-Schlüssel und die restrict-Option in authorized_keys sorgen dafür, dass jeder Client nur auf sein eigenes Backup-Repository zugreifen kann.

2. **Isolierung:**
   - Docker-Container trennen den Borg-Server vom Hostsystem und anderen Diensten, was das Risiko von Störungen oder ungewolltem Datenzugriff verringert.

3. **Portabilität:**
   - Die Lösung funktioniert auf jedem NAS oder Server mit Docker-Unterstützung (z.B. Synology, QNAP, UGREEN, TerraMaster) und ist einfach zu deployen oder zu migrieren.

4. **Einfache Updates und Wartung:**
   - Updates für Borg oder Abhängigkeiten werden durch ein einfaches Aktualisieren oder Neubauen des Containers durchgeführt, ohne das Hostsystem zu beeinflussen.

5. **Vereinfachte Rechtevergabe:**
   - Es ist nicht nötig, Backup-Nutzern Admin- oder Root-Rechte zu geben. Jeder Client arbeitet mit minimalen Rechten nur in seinem eigenen Repository.

6. **Konsistente Umgebung:**
   - Der Container stellt eine einheitliche Laufzeitumgebung (Alpine Linux, spezifische Borg-Version) bereit, was Kompatibilitätsprobleme auf verschiedenen NAS-Plattformen reduziert.

7. **Feingranulare Zugriffskontrolle:**
   - Die restrict-Option in authorized_keys erzwingt, dass jeder Client ausschließlich auf sein eigenes Backup-Verzeichnis zugreifen kann - auch bei Manipulationsversuchen.

8. **Einfache Wiederherstellung:**
   - Bei Problemen kann einfach auf ein vorheriges Container-Image oder eine frühere Konfiguration zurückgerollt werden, ohne das Hostsystem zu beeinträchtigen.

9. **Laufzeit-Hardening:**
   - Der Container läuft mit `no-new-privileges`, einer minimalen Capability-Whitelist und `tmpfs`-Mounts für `/run` und `/tmp`, was die Angriffsfläche zur Laufzeit reduziert.

10. **Secrets bleiben lokal:**
    - `.env`-, `.env.prod`- und `.env.test`-Dateien werden lokal und unverfolgt gehalten, damit sensible Konfiguration nie in die Versionskontrolle gelangt.

Dieses Konzept vereint Sicherheit, Flexibilität und Benutzerfreundlichkeit - ideal für Multi-User-Backups auf gemeinsam genutzten NAS-Systemen.

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
>
> **BorgBackup-Paket unter Alpine 3.23:** Dieses Projekt verwendet aktuell `borgbackup` in Version `1.4.3-r0` aus Alpine `v3.23`. Paket-Referenz: [pkgs.alpinelinux.org (borgbackup, v3.23)](https://pkgs.alpinelinux.org/packages?name=borgbackup&branch=v3.23&repo=&arch=&origin=&flagged=&maintainer=)

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
   - `SSH_LOG_LEVEL` (`VERBOSE` Standard, `DEBUG2`/`DEBUG3` für tiefere Analyse)
   - `SSH_CONFIG_DIR`
   - `AUTHORIZED_KEYS_FILE`
   - `BORG_REPOS_DIR`
   - `BORG_USER`, `BORG_UID`, `BORG_GID`

3. Host-Pfade anlegen und Berechtigungen setzen:

   Erwartete NAS-Struktur (Beispiel):

   ```text
   /volume1/
   └── borg-backups/                              # NAS-Share (oder borg-backups-prod / borg-backups-test)
       ├── config/
       │   ├── authorized_keys                    # diese Datei manuell anlegen
       │   └── ssh/                               # dieses Verzeichnis manuell anlegen
       │       ├── ssh_host_rsa_key               # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       │       ├── ssh_host_rsa_key.pub           # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       │       ├── ssh_host_ecdsa_key             # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       │       ├── ssh_host_ecdsa_key.pub         # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       │       ├── ssh_host_ed25519_key           # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       │       └── ssh_host_ed25519_key.pub       # wird beim ersten Container-Start erzeugt (falls nicht vorhanden)
       └── repos/                                 # Borg-Repositories (client-host-a, client-host-b, ...)
   ```

   Hinweis: Persistente SSH-Host-Keys unter `config/ssh` werden beim Container-Start automatisch erzeugt, wenn sie noch nicht existieren.

   Option A (CLI-Beispiel, Synology-SSH-Shell):

   ```bash
   SHARE_ROOT=/volume1/borg-backups

   mkdir -p "$SHARE_ROOT/config/ssh"
   mkdir -p "$SHARE_ROOT/repos"
   touch "$SHARE_ROOT/config/authorized_keys"

   chown -R <BORG_UID>:<BORG_GID> "$SHARE_ROOT/repos"
   chown <BORG_UID>:<BORG_GID> "$SHARE_ROOT/config/authorized_keys"

   chmod 750 "$SHARE_ROOT/repos"
   chmod 600 "$SHARE_ROOT/config/authorized_keys"
   ```

   Option B (Synology DSM 7 UI-Beispiel):
   - Öffne **Systemsteuerung > Gemeinsamer Ordner** und erstelle einen Share, z.B. `borg-backups`.
   - Öffne **File Station** und lege darin die Ordner `config` und `repos` an.
   - Lege in `config` den Ordner `ssh` und die Datei `authorized_keys` an.
   - Setze die Berechtigungen so, dass der Backup-Benutzer (UID/GID aus `.env`) auf `repos` und `authorized_keys` zugreifen kann.
   - Host-Key-Dateien nicht manuell anlegen; der Container erstellt sie beim ersten Start in `config/ssh`.

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
docker compose logs -f --timestamps sshd
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
   docker compose --env-file .env.prod -p borg-prod logs -f --timestamps sshd
   docker compose --env-file .env.test -p borg-test logs -f --timestamps sshd
   ```

5. Stacks stoppen:

   ```bash
   docker compose --env-file .env.prod -p borg-prod down
   docker compose --env-file .env.test -p borg-test down
   ```

Das trennt Schlüssel, Repositories, SSH-Fingerprints und Änderungen sauber zwischen Prod und Test.

### Image-Verhalten bei Prod/Test-Stacks

Standardmäßig ist der Image-*Name* gleich (`synology-borg-server:local`), aber die Image-*ID* (Digest) kann zwischen Prod und Test unterschiedlich sein.

Warum das passiert:
- Wenn `up --build` separat für Prod und Test ausgeführt wird, entstehen zwei getrennte Builds.
- Jeder Build kann eine neue Image-ID erzeugen.
- Bestehende Container behalten immer exakt den Digest, mit dem sie erstellt wurden.

Standard-Workflow (kann zu unterschiedlichen Image-IDs führen):

```bash
docker compose --env-file .env.prod -p borg-prod up -d --build
docker compose --env-file .env.test -p borg-test up -d --build
```

Beispiel für `docker ps -a` (Standardverhalten mit Unterschieden):

```text
CONTAINER ID   IMAGE                       PORTS                           NAMES
ec18ea89fb05   ef11a86a2243                0.0.0.0:2222->22/tcp            borg-prod-sshd-1
39d1db502e93   synology-borg-server:local  0.0.0.0:2223->22/tcp            borg-test-sshd-1
```

Wenn beide Stacks exakt denselben Image-Digest nutzen sollen, einmal bauen und beide Container ohne erneuten Build neu erstellen:

```bash
# 1) Einmal bauen
docker compose --env-file .env.prod -p borg-prod build sshd

# 2) Beide Stacks aus genau diesem Image neu erstellen
docker compose --env-file .env.prod -p borg-prod up -d --force-recreate --no-build
docker compose --env-file .env.test -p borg-test up -d --force-recreate --no-build
```

Beispiel für `docker ps -a` (gleiches Verhalten für beide Stacks):

```text
CONTAINER ID   IMAGE                       PORTS                           NAMES
aa11bb22cc33   synology-borg-server:local  0.0.0.0:2222->22/tcp            borg-prod-sshd-1
dd44ee55ff66   synology-borg-server:local  0.0.0.0:2223->22/tcp            borg-test-sshd-1
```

Zur direkten Digest-Prüfung:

```bash
docker inspect -f '{{.Name}} -> {{.Image}}' borg-prod-sshd-1 borg-test-sshd-1
```

> **Troubleshooting:** `docker ps -a` kann weiterhin eine kurze Image-ID statt `synology-borg-server:local` anzeigen, wenn an diesem Digest lokal aktuell kein Tag hängt. Nutze in diesem Fall die obige Digest-Prüfung als verlässliche Quelle.

## Wie Clients sich verbinden

Sobald der Borg-Server installiert und konfiguriert ist, kann er Backup-Jobs von beliebigen Clients per SSH-Schlüssel-Authentifizierung und Borg-Protokoll über eine `rsh`-Verbindung empfangen. Als Client kann jedes System mit installiertem BorgBackup und Netzwerkzugriff auf den SSH-Port des Servers dienen.

```
   ┌──────────────────────────┐             ┌────────────────────────────────────────────┐
   │      Client Host A       │             │          NAS / Linux-Server                │
   ├──────────────────────────┤             │                                            │
   │  $ borg create / prune   │             │  ┌──────────────────────────────────────┐  │
   │  BORG_RSH=               │             │  │         Docker Container             │  │
   │   "ssh -p 2222           ├─SSH:2222───►│  │  sshd [:22]     borgbackup           │  │
   │    -i ~/.ssh/key_a"      │             │  │                                      │  │
   └──────────────────────────┘             │  │  authorized_keys                     │  │
                                            │  │  └─► borg serve --restrict-to-path   │  │
   ┌──────────────────────────┐             │  │                                      │  │
   │      Client Host B       │             │  │  /var/backup/borg/                   │  │
   │                          │             │  │  ├── client-host-a/ (Repo A)         │  │
   │  $ borg create / prune   ├─SSH:2222───►│  │  └── client-host-b/ (Repo B)         │  │
   │  BORG_RSH=               │             │  └──────────────────┬───────────────────┘  │
   │   "ssh -p 2222           │             │                     │ Volume-Mount         │
   │    -i ~/.ssh/key_b"      │             │  ┌──────────────────▼───────────────────┐  │
   └──────────────────────────┘             │  │              NAS-Speicher            │  │
                                            │  │  /volume1/borg-backups/repos/        │  │
                                            │  │  ├── client-host-a/ (Repo A)         │  │
                                            │  │  └── client-host-b/ (Repo B)         │  │
                                            │  └──────────────────────────────────────┘  │
                                            └────────────────────────────────────────────┘
```

**Ablauf:**
- Der Client führt Borg-Befehle aus (z.B. `borg create`, `borg extract`) und setzt `BORG_RSH` auf SSH mit dem passenden Schlüssel.
- Der Server authentifiziert den Client per SSH-Schlüssel und beschränkt den Zugriff auf das zugewiesene Repository.
- Die gesamte Datenübertragung erfolgt verschlüsselt über SSH und wird auf dem angegebenen Volume-Mount gespeichert.

### Vollständiger Ablauf (erste Client-Einrichtung)

1. SSH-Schlüsselpaar auf dem Client erzeugen (empfohlen: `ed25519`):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/borg_client_ed25519 -C "client-host-a-key"
   ```

2. Öffentlichen Schlüssel ausgeben:

   ```bash
   cat ~/.ssh/borg_client_ed25519.pub
   ```

3. Öffentlichen Schlüssel mit Einschränkung in `authorized_keys` auf dem Server eintragen:

   ```text
   command="borg serve --restrict-to-path /var/backup/borg/client-host-a",restrict ssh-ed25519 AAAA...dein-public-key... client-host-a-key
   ```

4. Container neu laden, damit die Änderung übernommen wird.
   Hinweis: Nach jeder Änderung an `authorized_keys` den Container neu starten oder neu erstellen. Ein Rebuild ist nicht erforderlich.

   ```bash
   docker compose up -d --build
   # oder
   docker compose restart sshd
   ```

5. Repository vom Client aus initialisieren:

   ```bash
   export BORG_RSH='ssh -p <SSH_PORT> -i ~/.ssh/borg_client_ed25519 -o IdentitiesOnly=yes'
   borg init --encryption=repokey-blake2 ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-a
   ```

6. Erstes Backup erstellen:

   ```bash
   borg create --stats ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-a::erstes-backup-$(date +%Y-%m-%d) /pfad/zu/deinen/daten
   ```

7. Repository-Informationen prüfen:

   ```bash
   borg info ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-a
   ```

8. Verfügbare Archive im Repository auflisten:

   ```bash
   borg list ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-a
   ```

9. Inhalt des erstellten Archivs anzeigen:

   ```bash
   borg list ssh://<BORG_USER>@<BACKUP_SERVER_HOST>/var/backup/borg/client-host-a::erstes-backup-<DATUM>
   ```

---

## Beispiel-Repository-URLs für Clients

Empfohlen: Repository-URL ohne expliziten Port nutzen und SSH-Details über `BORG_RSH` setzen.
`BORG_RSH` in der Client-Umgebung definieren, um den SSH-Befehl mit dem richtigen Port und der passenden Identitätsdatei anzugeben. Das hält die Borg-Befehle übersichtlich und konsistent.
Die Variable `BORG_RSH` in der Shell-Konfiguration oder vor dem Ausführen von Borg-Befehlen exportieren und das Standard-SSH-URL-Format für Repositories verwenden. Der Server verarbeitet die Verbindung anhand der angegebenen SSH-Optionen.

Beispiel für das Setzen von `BORG_RSH` und das Initialisieren eines Repositories:

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
### Protokollierung

Die SSH-Log-Detailtiefe steuerst du über `SSH_LOG_LEVEL` in der Environment-Datei. Für den Normalbetrieb ist `VERBOSE` geeignet, für detailliertes Troubleshooting `DEBUG2` oder `DEBUG3`.

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
