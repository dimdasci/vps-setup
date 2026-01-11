# Workflows

## Overview

Four main workflows handle the complete lifecycle:
1. **Provisioning** - Set up a bare Ubuntu VPS from scratch
2. **Deployment** - Update configuration on an existing installation
3. **Validation** - Verify all services are healthy
4. **DNS Management** - Synchronize DNS records via Netcup API

## 1. Provisioning Workflow

Full provisioning takes a bare Ubuntu VPS to a running state with all services.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PROVISIONING WORKFLOW                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PHASE 1: PRE-FLIGHT CHECKS                                         │
│  ──────────────────────────                                         │
│  ├─ Verify SSH connectivity (root access)                           │
│  ├─ Detect Ubuntu version (require 22.04 LTS or later)              │
│  ├─ Check available disk space (require >20GB)                      │
│  ├─ Check available memory (require >8GB)                           │
│  ├─ Validate configuration files locally                            │
│  └─ Decrypt secrets and validate                                    │
│                                                                      │
│  PHASE 2: SYSTEM PREPARATION                                        │
│  ───────────────────────────                                        │
│  ├─ Update package lists (apt update)                               │
│  ├─ Upgrade existing packages (apt upgrade -y)                      │
│  ├─ Install essential packages:                                     │
│  │   └─ curl wget git jq unzip ca-certificates gnupg lsb-release   │
│  ├─ Configure automatic security updates                            │
│  │   └─ unattended-upgrades                                         │
│  └─ Set timezone to configured value                                │
│                                                                      │
│  PHASE 3: USER CREATION                                             │
│  ──────────────────────                                             │
│  ├─ Create 'app' user for Docker operations                         │
│  │   ├─ Home: /home/app                                             │
│  │   ├─ Groups: docker (added after Docker install)                 │
│  │   └─ SSH: Copy authorized_keys from root                         │
│  │                                                                   │
│  └─ Create 'mox' user for email server                             │
│      ├─ Home: /home/mox                                             │
│      ├─ System user (no login shell)                                │
│      └─ Owns /home/mox/certs, /home/mox/data                       │
│                                                                      │
│  PHASE 4: FIREWALL CONFIGURATION                                    │
│  ───────────────────────────────                                    │
│  ├─ Install UFW if not present                                      │
│  ├─ Reset to defaults                                               │
│  ├─ Default deny incoming, allow outgoing                           │
│  ├─ Allow rules:                                                    │
│  │   ├─ 22/tcp    SSH                                               │
│  │   ├─ 80/tcp    HTTP                                              │
│  │   ├─ 443/tcp   HTTPS                                             │
│  │   ├─ 5432/tcp  PostgreSQL (optional, for admin)                  │
│  │   ├─ 25/tcp    SMTP                                              │
│  │   ├─ 465/tcp   SMTPS                                             │
│  │   ├─ 587/tcp   SMTP Submission                                   │
│  │   └─ 993/tcp   IMAPS                                             │
│  ├─ Allow from Docker networks (172.16.0.0/12) to port 8080         │
│  └─ Enable UFW                                                      │
│                                                                      │
│  PHASE 5: DOCKER INSTALLATION                                       │
│  ────────────────────────────                                       │
│  ├─ Add Docker's official GPG key                                   │
│  ├─ Add Docker apt repository                                       │
│  ├─ Install packages:                                               │
│  │   └─ docker-ce docker-ce-cli containerd.io docker-compose-plugin│
│  ├─ Add 'app' user to docker group                                  │
│  ├─ Enable Docker service on boot                                   │
│  └─ Verify: docker --version, docker compose version                │
│                                                                      │
│  PHASE 6: HOST SERVICES (Mox)                                       │
│  ────────────────────────────                                       │
│  ├─ Download Mox binary from beta.gobuilds.org                      │
│  ├─ Verify binary (ELF 64-bit check)                                │
│  ├─ Install to /home/mox/mox                                        │
│  ├─ Create directories:                                             │
│  │   ├─ /home/mox/data                                              │
│  │   └─ /home/mox/certs                                             │
│  ├─ Run quickstart (generates initial config)                       │
│  │   └─ NOTE: May require interactive DNS verification              │
│  ├─ Upload mox.conf from templates                                  │
│  ├─ Create systemd service                                          │
│  │   └─ /etc/systemd/system/mox.service                             │
│  ├─ Configure log rotation                                          │
│  │   └─ /etc/logrotate.d/mox                                        │
│  ├─ Enable and start service                                        │
│  ├─ Retrieve DKIM public key for DNS                                │
│  │   └─ mox config domain keyget <domain>                           │
│  └─ Verify: systemctl status mox                                    │
│                                                                      │
│  PHASE 6.5: DNS SYNCHRONIZATION (Netcup)                            │
│  ───────────────────────────────────────                            │
│  ├─ Authenticate with Netcup DNS API                                │
│  │   └─ POST https://ccp.netcup.net/.../endpoint.php?JSON           │
│  ├─ For each configured zone:                                       │
│  │   ├─ Verify zone exists (infoDnsZone)                            │
│  │   ├─ Get current records (infoDnsRecords)                        │
│  │   └─ Calculate required records:                                 │
│  │       ├─ A records: mail, mta-sts, autoconfig, app subdomains    │
│  │       ├─ MX: @ → mail.<domain> (priority 10)                     │
│  │       ├─ TXT: SPF (v=spf1 mx ~all)                               │
│  │       ├─ TXT: DMARC (_dmarc)                                     │
│  │       ├─ TXT: DKIM (<selector>._domainkey)                       │
│  │       ├─ TXT: MTA-STS (_mta-sts)                                 │
│  │       └─ TXT: TLSRPT (_smtp._tls)                                │
│  ├─ Show diff and confirm (unless --yes)                            │
│  ├─ Update zone records (updateDnsRecords)                          │
│  │   └─ NOTE: Netcup replaces ALL records, send complete set        │
│  ├─ Wait for propagation (default: 15 min)                          │
│  │   └─ Check via dig @8.8.8.8, @1.1.1.1                            │
│  ├─ Validate records propagated                                     │
│  └─ Log out from API session                                        │
│                                                                      │
│  PHASE 7: DOCKER ENVIRONMENT SETUP                                  │
│  ─────────────────────────────────                                  │
│  ├─ Create directory: /home/app/docker                              │
│  ├─ Generate configuration files:                                   │
│  │   ├─ docker-compose.yml (from services.yaml)                     │
│  │   ├─ Caddyfile (from services.yaml)                              │
│  │   ├─ init-db.sh (from postgres.databases)                        │
│  │   ├─ .env (from secrets.enc.yaml)                                │
│  │   ├─ postgresql.conf                                             │
│  │   ├─ pg_hba.conf                                                 │
│  │   └─ zitadel-config.yaml                                         │
│  ├─ Upload windmill-worker/Dockerfile                               │
│  ├─ Set ownership: chown -R app:app /home/app/docker                │
│  └─ Set permissions: chmod 600 .env                                 │
│                                                                      │
│  PHASE 8: DOCKER SERVICES DEPLOYMENT                                │
│  ───────────────────────────────────                                │
│  ├─ As 'app' user:                                                  │
│  │   ├─ cd /home/app/docker                                         │
│  │   ├─ docker compose pull                                         │
│  │   ├─ docker compose build (for custom images)                    │
│  │   └─ docker compose up -d                                        │
│  │                                                                   │
│  ├─ Wait for health checks (with timeout):                          │
│  │   ├─ postgres: pg_isready (30s start_period)                     │
│  │   ├─ redis: ping response                                        │
│  │   ├─ caddy: HTTP 200 on port 80                                  │
│  │   └─ All other services                                          │
│  │                                                                   │
│  └─ Record deployment state                                         │
│                                                                      │
│  PHASE 9: CERTIFICATE SYNC                                          │
│  ─────────────────────────                                          │
│  ├─ Wait for Caddy to obtain certificates (~2-5 min)                │
│  │   └─ Check: /data/caddy/certificates/.../mail.fidudoc.eu/       │
│  ├─ Extract mail.fidudoc.eu cert and key                            │
│  ├─ Deploy to /home/mox/certs/                                      │
│  │   └─ Set permissions: chown mox:mox, chmod 600/644               │
│  ├─ Reload Mox: systemctl reload mox                                │
│  ├─ Install cron job for ongoing sync                               │
│  │   └─ 0 */6 * * * /usr/local/bin/vps-cert-sync                   │
│  └─ Verify TLS: openssl s_client -connect mail.fidudoc.eu:993      │
│                                                                      │
│  PHASE 10: VALIDATION                                               │
│  ────────────────────                                               │
│  ├─ Run all health checks (see Validation Workflow)                 │
│  ├─ Check logs for errors                                           │
│  ├─ Verify external accessibility                                   │
│  └─ Generate provisioning report                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Provisioning Output Example

```
VPS Provisioning Report
=======================

Host: 203.0.113.50
Started: 2025-01-09T10:00:00Z
Completed: 2025-01-09T10:25:00Z
Duration: 25 minutes

Phases:
  [✓] Pre-flight checks           (5s)
  [✓] System preparation          (2m 30s)
  [✓] User creation               (3s)
  [✓] Firewall configuration      (5s)
  [✓] Docker installation         (1m 45s)
  [✓] Mox installation            (45s)
  [✓] DNS synchronization         (15m 30s)  ← Netcup propagation
  [✓] Docker environment setup    (15s)
  [✓] Docker services deployment  (8m 30s)
  [✓] Certificate sync            (3m 20s)
  [✓] Validation                  (30s)

Services Running:
  [✓] caddy            healthy
  [✓] postgres         healthy
  [✓] redis            healthy
  [✓] zitadel          healthy
  [✓] zitadel-login    healthy
  [✓] windmill-server  healthy
  [✓] windmill-worker  healthy (2 replicas)
  [✓] windmill-lsp     running
  [✓] postfix-relay    running
  [✓] mox              healthy (systemd)

Endpoints:
  [✓] https://fidudoc.eu          200 OK
  [✓] https://auth.fidudoc.eu     200 OK
  [✓] https://wm.fidudoc.eu       200 OK
  [✓] https://mail.fidudoc.eu     200 OK

Certificates:
  [✓] *.fidudoc.eu                valid until 2025-04-09
  [✓] mail.fidudoc.eu             synced to Mox

Result: SUCCESS
```

## 2. Deployment Workflow

Updates an existing installation with configuration changes.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT WORKFLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PHASE 1: PRE-DEPLOYMENT                                            │
│  ───────────────────────                                            │
│  ├─ Verify SSH connectivity (app user)                              │
│  ├─ Load current deployment state from server                       │
│  ├─ Validate new configuration locally                              │
│  ├─ Decrypt secrets                                                 │
│  └─ Calculate diff (what needs to change)                           │
│                                                                      │
│  PHASE 2: STATE BACKUP                                              │
│  ─────────────────────                                              │
│  ├─ Create backup directory:                                        │
│  │   └─ /home/app/docker/.vps-state/backups/<timestamp>/           │
│  ├─ Copy current files:                                             │
│  │   ├─ docker-compose.yml                                          │
│  │   ├─ Caddyfile                                                   │
│  │   └─ .env (encrypted)                                            │
│  ├─ Record container image digests                                  │
│  └─ Store backup metadata                                           │
│                                                                      │
│  PHASE 3: CONFIGURATION GENERATION                                  │
│  ─────────────────────────────────                                  │
│  ├─ Generate new configuration files                                │
│  ├─ Compare with current (show diff)                                │
│  │                                                                   │
│  │   Changes detected:                                              │
│  │   - docker-compose.yml: 3 services modified                      │
│  │   - Caddyfile: 1 site added                                      │
│  │   - .env: 2 variables changed                                    │
│  │                                                                   │
│  └─ Prompt for confirmation (unless --yes flag)                     │
│                                                                      │
│  PHASE 4: STAGED DEPLOYMENT                                         │
│  ──────────────────────────                                         │
│  │                                                                   │
│  ├─ CASE A: Config-only changes (no image updates)                  │
│  │   ├─ Upload new config files                                     │
│  │   ├─ Reload Caddy: docker exec caddy caddy reload                │
│  │   └─ Restart affected services only                              │
│  │                                                                   │
│  ├─ CASE B: Image updates                                           │
│  │   ├─ Pull new images: docker compose pull                        │
│  │   ├─ For each updated service (in dependency order):             │
│  │   │   ├─ Stop service                                            │
│  │   │   ├─ Start with new image                                    │
│  │   │   ├─ Wait for health check                                   │
│  │   │   └─ On failure: rollback and stop                           │
│  │   └─ Clean up old images                                         │
│  │                                                                   │
│  └─ CASE C: Service enable/disable changes                          │
│      ├─ Stop removed services                                       │
│      ├─ Remove from docker-compose.yml                              │
│      ├─ Add new services to docker-compose.yml                      │
│      ├─ Start new services                                          │
│      └─ Note: Database data is preserved                            │
│                                                                      │
│  PHASE 5: DATABASE MIGRATIONS                                       │
│  ────────────────────────────                                       │
│  ├─ Check for new databases needed                                  │
│  │   └─ Compare services.databases with existing DBs                │
│  ├─ Create new databases and users                                  │
│  └─ Note: Never drop databases automatically                        │
│                                                                      │
│  PHASE 6: HOST SERVICE UPDATES (Mox)                                │
│  ───────────────────────────────────                                │
│  ├─ Check Mox config changes                                        │
│  ├─ If config changed:                                              │
│  │   ├─ Upload new mox.conf                                         │
│  │   └─ Reload: systemctl reload mox                                │
│  └─ If binary update requested:                                     │
│      ├─ Download new binary                                         │
│      ├─ Stop Mox                                                    │
│      ├─ Replace binary                                              │
│      ├─ Start Mox                                                   │
│      └─ Verify health                                               │
│                                                                      │
│  PHASE 7: POST-DEPLOYMENT                                           │
│  ────────────────────────                                           │
│  ├─ Run health checks                                               │
│  ├─ Sync certificates if needed                                     │
│  ├─ Update deployment state record                                  │
│  └─ Generate deployment report                                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Deployment Diff Example

```
Configuration Diff
==================

docker-compose.yml:
  services.windmill-server.environment:
-   MODE: "server"
+   MODE: "standalone"

  services.windmill-lsp:
-   enabled: true
+   enabled: false  # Service will be stopped

  services.grafana:  # NEW SERVICE
+   enabled: true
+   image: grafana/grafana:latest
+   ...

Caddyfile:
+ metrics.fidudoc.eu {
+     reverse_proxy grafana:3000
+ }

.env:
  WINDMILL_MODE changed

Actions to perform:
  1. Stop windmill-lsp container
  2. Update windmill-server environment
  3. Add grafana service
  4. Reload Caddy configuration
  5. Create grafana database

Proceed? [y/N]
```

### Rollback Mechanism

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ROLLBACK WORKFLOW                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. List available rollback points:                                 │
│     vps rollback --list                                             │
│                                                                      │
│     Available rollback points:                                      │
│     [1] 2025-01-09T10:30:00 (current - 2 hours ago)                │
│     [2] 2025-01-08T15:45:00 (1 day ago)                            │
│     [3] 2025-01-07T09:00:00 (2 days ago)                           │
│                                                                      │
│  2. Execute rollback:                                               │
│     vps rollback --version 2025-01-08T15:45:00                     │
│                                                                      │
│  3. Rollback steps:                                                 │
│     ├─ Stop all containers                                          │
│     ├─ Restore backed-up config files                               │
│     ├─ Restore previous image versions (if stored)                  │
│     ├─ Start containers                                             │
│     ├─ Wait for health checks                                       │
│     └─ Update state to mark rollback                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 3. Validation Workflow

Comprehensive health check after deployment or on-demand.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VALIDATION WORKFLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  CATEGORY 1: INFRASTRUCTURE CHECKS                                  │
│  ─────────────────────────────────                                  │
│  │                                                                   │
│  ├─ System Resources:                                               │
│  │   ├─ [CHECK] Disk space > 20% free                              │
│  │   ├─ [CHECK] Memory usage < 90%                                  │
│  │   └─ [CHECK] Load average < CPU count × 2                        │
│  │                                                                   │
│  ├─ Network:                                                        │
│  │   ├─ [CHECK] DNS resolution working                              │
│  │   │   └─ Resolve: google.com, fidudoc.eu                        │
│  │   ├─ [CHECK] External connectivity                               │
│  │   │   └─ Ping: 8.8.8.8, 1.1.1.1                                 │
│  │   └─ [CHECK] Docker networks exist                               │
│  │       └─ List: web, zitadel-internal, windmill-internal         │
│  │                                                                   │
│  └─ Firewall:                                                       │
│      └─ [CHECK] Required ports accessible                           │
│          └─ Scan: 22, 80, 443, 25, 587, 993                        │
│                                                                      │
│  CATEGORY 2: DOCKER CONTAINER CHECKS                                │
│  ───────────────────────────────────                                │
│  │                                                                   │
│  ├─ Container Status:                                               │
│  │   ├─ [CHECK] All expected containers running                     │
│  │   │   └─ Compare: services.yaml enabled vs docker ps            │
│  │   ├─ [CHECK] No containers in restart loop                       │
│  │   │   └─ Check: RestartCount < 5 in last hour                   │
│  │   └─ [CHECK] Resource limits not exceeded                        │
│  │       └─ Check: docker stats vs configured limits                │
│  │                                                                   │
│  └─ Per-Container Health:                                           │
│      ├─ caddy:                                                      │
│      │   └─ [CHECK] HTTP 200 on localhost:80                       │
│      ├─ postgres:                                                   │
│      │   └─ [CHECK] pg_isready -h localhost -U postgres            │
│      ├─ redis:                                                      │
│      │   └─ [CHECK] redis-cli ping → PONG                          │
│      ├─ zitadel:                                                    │
│      │   └─ [CHECK] /app/zitadel ready                             │
│      ├─ zitadel-login:                                              │
│      │   └─ [CHECK] HTTP 200 on localhost:3000/healthz             │
│      ├─ windmill-server:                                            │
│      │   └─ [CHECK] HTTP 200 on localhost:8000/api/version         │
│      ├─ windmill-worker:                                            │
│      │   └─ [CHECK] Log contains "worker started" (recent)          │
│      └─ windmill-lsp:                                               │
│          └─ [CHECK] Process running                                 │
│                                                                      │
│  CATEGORY 3: ENDPOINT CHECKS                                        │
│  ───────────────────────────                                        │
│  │                                                                   │
│  ├─ HTTPS Endpoints (external access):                              │
│  │   ├─ [CHECK] https://fidudoc.eu          → 200                  │
│  │   ├─ [CHECK] https://auth.fidudoc.eu     → 200                  │
│  │   ├─ [CHECK] https://wm.fidudoc.eu       → 200                  │
│  │   └─ [CHECK] https://mail.fidudoc.eu     → 200                  │
│  │                                                                   │
│  └─ Database Connectivity:                                          │
│      ├─ [CHECK] zitadel → postgres (zitadel database)              │
│      └─ [CHECK] windmill → postgres + redis                        │
│                                                                      │
│  CATEGORY 4: CERTIFICATE CHECKS                                     │
│  ──────────────────────────────                                     │
│  │                                                                   │
│  ├─ Caddy Certificates:                                             │
│  │   ├─ [CHECK] All domains have valid certs                       │
│  │   ├─ [CHECK] Certs not expiring < 14 days                        │
│  │   │   └─ Warn if < 14 days, fail if < 3 days                    │
│  │   └─ [CHECK] Certificate chain valid                             │
│  │                                                                   │
│  └─ Mox Certificates:                                               │
│      ├─ [CHECK] Cert exists: /home/mox/certs/mail.fidudoc.eu.crt   │
│      ├─ [CHECK] Key exists: /home/mox/certs/mail.fidudoc.eu.key    │
│      ├─ [CHECK] Cert matches domain                                 │
│      ├─ [CHECK] Cert not expired                                    │
│      └─ [CHECK] Cert matches Caddy cert (synced)                    │
│                                                                      │
│  CATEGORY 5: HOST SERVICE CHECKS (Mox)                              │
│  ─────────────────────────────────────                              │
│  │                                                                   │
│  ├─ Systemd:                                                        │
│  │   ├─ [CHECK] mox.service active                                 │
│  │   └─ [CHECK] No recent crashes (< 24h)                          │
│  │                                                                   │
│  ├─ Port Connectivity:                                              │
│  │   ├─ [CHECK] Port 25 accepting (SMTP)                           │
│  │   ├─ [CHECK] Port 465 accepting (SMTPS)                         │
│  │   ├─ [CHECK] Port 587 accepting (Submission)                    │
│  │   └─ [CHECK] Port 993 accepting (IMAPS)                         │
│  │                                                                   │
│  └─ Configuration:                                                  │
│      └─ [CHECK] mox config test passes                             │
│                                                                      │
│  CATEGORY 6: LOG ANALYSIS                                           │
│  ────────────────────────                                           │
│  │                                                                   │
│  ├─ Docker Logs (last 1 hour):                                     │
│  │   ├─ [CHECK] No ERROR patterns                                  │
│  │   ├─ [CHECK] No FATAL patterns                                  │
│  │   ├─ [CHECK] No "connection refused"                            │
│  │   └─ [CHECK] No authentication failures                         │
│  │                                                                   │
│  └─ System Logs:                                                    │
│      ├─ [CHECK] journalctl -u mox for errors                       │
│      └─ [CHECK] /var/log/syslog for system issues                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Validation Report Format

```
VPS Validation Report
=====================

Host: 203.0.113.50
Timestamp: 2025-01-09T12:30:00Z
Duration: 45 seconds

Summary:
  Total Checks: 36
  Passed: 34
  Warnings: 1
  Failed: 1

Status: WARN

─────────────────────────────────────────────────────────

Infrastructure (8/8 passed)
  [✓] Disk space           56% free (108GB available)
  [✓] Memory usage         72% (8.6GB / 12GB)
  [✓] CPU load             1.2 (6 cores)
  [✓] DNS resolution       OK
  [✓] External connectivity OK
  [✓] Docker networks      3 networks found
  [✓] Port 80 accessible   OK
  [✓] Port 443 accessible  OK

Containers (9/9 passed)
  [✓] caddy                running, healthy
  [✓] postgres             running, healthy
  [✓] redis                running, healthy
  [✓] zitadel              running, healthy
  [✓] zitadel-login        running, healthy
  [✓] windmill-server      running, healthy
  [✓] windmill-worker-1    running
  [✓] windmill-worker-2    running
  [✓] windmill-lsp         running

Endpoints (4/4 passed)
  [✓] https://fidudoc.eu         200 OK (234ms)
  [✓] https://auth.fidudoc.eu    200 OK (145ms)
  [✓] https://wm.fidudoc.eu      200 OK (167ms)
  [✓] https://mail.fidudoc.eu    200 OK (112ms)

Certificates (4/5 passed, 1 warning)
  [✓] Caddy certs valid          All domains OK
  [⚠] Cert expiry                mail.fidudoc.eu expires in 12 days
  [✓] Cert chain valid           OK
  [✓] Mox cert exists            OK
  [✓] Mox cert synced            Matches Caddy

Host Services (4/5 passed, 1 failed)
  [✓] mox.service active         OK
  [✓] Port 25 accessible         OK
  [✗] Port 465 accessible        Connection refused
  [✓] Port 587 accessible        OK
  [✓] Port 993 accessible        OK

Logs (6/6 passed)
  [✓] Docker ERROR patterns      0 found
  [✓] Docker FATAL patterns      0 found
  [✓] Connection refused         0 found
  [✓] Auth failures              0 found
  [✓] Mox errors                 0 found
  [✓] System errors              0 found

─────────────────────────────────────────────────────────

Issues:

  [FAIL] Port 465 accessible
         Port 465 (SMTPS) is not accepting connections.
         This may indicate Mox TLS configuration issue.
         Check: sudo ss -tlnp | grep 465
         Check: journalctl -u mox --since "1 hour ago"

  [WARN] Cert expiry
         mail.fidudoc.eu expires in 12 days.
         Certificate sync should renew automatically.
         Check: vps cert-sync --host 203.0.113.50

─────────────────────────────────────────────────────────

Recommendations:
  1. Investigate port 465 issue immediately
  2. Monitor certificate renewal in next 48 hours
```

## Implementation Notes

### Idempotency

All workflow steps must be idempotent - safe to run multiple times:

```typescript
// Example: User creation is idempotent
async function createUser(ssh: SSHClient, username: string): Promise<void> {
  const exists = await ssh.exec(`id ${username} 2>/dev/null`);
  if (exists.exitCode === 0) {
    logger.info(`User ${username} already exists, skipping`);
    return;
  }

  await ssh.exec(`useradd -m -s /bin/bash ${username}`);
}
```

### Dependency Resolution

Services are started in dependency order:

```
1. postgres, redis (no dependencies)
2. caddy (no dependencies, but routes to others)
3. zitadel, windmill-server (depend on postgres)
4. zitadel-login (depends on zitadel)
5. windmill-worker, windmill-lsp (depend on windmill-server)
```

### Error Recovery

Each phase has a cleanup function for partial failure:

```typescript
interface Phase {
  name: string;
  execute(): Promise<void>;
  cleanup(): Promise<void>;  // Called on failure
}
```

## 4. DNS Management Workflow

DNS records are synchronized via Netcup DNS API. This workflow can run standalone or as part of provisioning.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DNS MANAGEMENT WORKFLOW                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PHASE 1: AUTHENTICATION                                            │
│  ───────────────────────                                            │
│  ├─ Load DNS credentials from secrets                               │
│  │   └─ customer_number, api_key, api_password                     │
│  ├─ Authenticate with Netcup DNS API                                │
│  │   └─ POST https://ccp.netcup.net/.../endpoint.php?JSON          │
│  │   └─ Action: login                                               │
│  └─ Store session ID for subsequent requests                        │
│                                                                      │
│  PHASE 2: ZONE DISCOVERY                                            │
│  ───────────────────────                                            │
│  ├─ For each configured zone (dns.zones):                          │
│  │   ├─ Verify zone exists in Netcup account                       │
│  │   │   └─ Action: infoDnsZone                                    │
│  │   ├─ Retrieve current records                                    │
│  │   │   └─ Action: infoDnsRecords                                 │
│  │   └─ Store current state for diffing                            │
│  │                                                                   │
│  └─ FAIL if zone not found                                          │
│      └─ User must add zone in Netcup CCP first                     │
│                                                                      │
│  PHASE 3: RECORD CALCULATION                                        │
│  ───────────────────────────                                        │
│  │                                                                   │
│  ├─ Infrastructure A Records (from VPS IP):                        │
│  │   ├─ mail.<domain>       → VPS_IP                               │
│  │   ├─ mta-sts.<domain>    → VPS_IP                               │
│  │   ├─ autoconfig.<domain> → VPS_IP                               │
│  │   └─ www.<domain>        → VPS_IP (if configured)               │
│  │                                                                   │
│  ├─ Application A Records (from profile.domains):                   │
│  │   └─ For each app with subdomain:                               │
│  │       └─ <subdomain>.<domain> → VPS_IP                          │
│  │                                                                   │
│  ├─ Email Records:                                                  │
│  │   ├─ MX:  @          → mail.<domain> (priority 10)              │
│  │   ├─ TXT: @          → v=spf1 mx ~all                           │
│  │   ├─ TXT: _dmarc     → v=DMARC1; p=quarantine; rua=mailto:...   │
│  │   ├─ TXT: <selector>._domainkey → DKIM public key               │
│  │   │   └─ Retrieved from: mox config domain keyget <domain>      │
│  │   ├─ TXT: _mta-sts   → v=STSv1; id=<hash>                       │
│  │   └─ TXT: _smtp._tls → v=TLSRPTv1; rua=mailto:...               │
│  │                                                                   │
│  └─ Compare calculated vs current → generate diff                   │
│                                                                      │
│  PHASE 4: RECORD SYNCHRONIZATION                                    │
│  ───────────────────────────────                                    │
│  ├─ Display diff (unless --quiet):                                  │
│  │                                                                   │
│  │   DNS Changes for dimosaic.com:                                 │
│  │   + A     newapp     203.0.113.50                               │
│  │   ~ TXT   _dmarc     (policy updated)                           │
│  │   - A     oldapp     (removed)                                  │
│  │                                                                   │
│  ├─ Confirm changes (unless --yes)                                  │
│  │                                                                   │
│  ├─ Apply changes via API:                                          │
│  │   └─ Action: updateDnsRecords                                   │
│  │       └─ IMPORTANT: Netcup replaces ALL records                 │
│  │       └─ Always send complete record set                        │
│  │                                                                   │
│  └─ Log out from API session                                        │
│                                                                      │
│  PHASE 5: PROPAGATION VALIDATION                                    │
│  ───────────────────────────────                                    │
│  ├─ Wait for propagation (default: 15 minutes for Netcup)          │
│  │   └─ Can be skipped with --no-wait                              │
│  │                                                                   │
│  ├─ Check records via public DNS resolvers:                         │
│  │   ├─ dig @8.8.8.8 A mail.<domain>                               │
│  │   ├─ dig @1.1.1.1 MX <domain>                                   │
│  │   ├─ dig @9.9.9.9 TXT <domain> (SPF)                            │
│  │   └─ dig @8.8.8.8 TXT _dmarc.<domain>                           │
│  │                                                                   │
│  └─ Report validation results                                       │
│      ├─ [✓] All records propagated                                  │
│      └─ [✗] <record> not yet visible (retry in X minutes)          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### DNS Workflow Triggers

| Trigger | Records Updated |
|---------|-----------------|
| `vps provision` | All records (A, MX, TXT) |
| `vps dns sync` | All records |
| `vps dns sync --zone <domain>` | Single zone only |
| `vps deploy` (with new app) | A record for new subdomain |

### Netcup API Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No per-record TTL | All records share zone TTL | Accept limitation |
| Slow propagation | ~15 minutes typical | Build in wait time |
| Full zone updates | Must send ALL records | Always merge with existing |
| Session timeout | 15 minute sessions | Login per operation batch |

### DKIM Key Retrieval

For DKIM records, the public key is retrieved from Mox:

```bash
# On VPS, executed via SSH
sudo -u mox /home/mox/mox config domain keyget dimosaic.com
# Output: selector=20250109, pubkey=MIIBIjANBgkqhki...
```

The output is parsed to construct the `<selector>._domainkey` TXT record.

---

## 5. CI/CD Workflows (GitHub Actions)

Application deployments are triggered via GitHub Actions from separate repositories.

### Frontend Deployment (Static)

```yaml
# .github/workflows/deploy.yml (in frontend repo)
name: Deploy Frontend

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  APP_NAME: personal-site
  DEPLOY_PATH: /var/www/dimosaic

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v1

      - name: Install dependencies
        run: bun install

      - name: Build
        run: bun run build
        env:
          VITE_API_URL: ${{ vars.API_URL }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/

      - name: Deploy to VPS
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.VPS_HOST }}
          username: app
          key: ${{ secrets.VPS_SSH_KEY }}
          source: "dist/*"
          target: ${{ env.DEPLOY_PATH }}
          strip_components: 1
          rm: true  # Clean target before copy

      - name: Notify deployment
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: app
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            echo "Deployed ${{ env.APP_NAME }} at $(date)" >> ~/deployments.log
```

### Backend Deployment (Container via GHCR)

```yaml
# .github/workflows/deploy.yml (in backend repo)
name: Deploy API

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  CONTAINER_NAME: personal-api

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU (for ARM builds)
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/arm64  # ARM for Netcup VPS
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: app
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd ~/docker

            # Login to GHCR
            echo "${{ secrets.GHCR_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

            # Pull new image
            docker compose pull ${{ env.CONTAINER_NAME }}

            # Recreate container with new image
            docker compose up -d --no-deps --force-recreate ${{ env.CONTAINER_NAME }}

            # Wait for health check
            sleep 10
            docker compose ps ${{ env.CONTAINER_NAME }}

            # Cleanup old images
            docker image prune -f

      - name: Verify deployment
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: app
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            # Check container is healthy
            docker inspect --format='{{.State.Health.Status}}' ${{ env.CONTAINER_NAME }} | grep -q healthy || exit 1
            echo "Deployment successful"
```

### Backend Deployment (Build on VPS)

Alternative approach for simpler setups or limited CI minutes:

```yaml
# .github/workflows/deploy.yml
name: Deploy API (Build on VPS)

on:
  push:
    branches: [main]

env:
  REPO_PATH: ~/repos/personal-api
  CONTAINER_NAME: personal-api

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: app
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            # Pull latest code
            cd ${{ env.REPO_PATH }}
            git fetch origin
            git reset --hard origin/main

            # Build and deploy
            cd ~/docker
            docker compose build ${{ env.CONTAINER_NAME }}
            docker compose up -d --no-deps --force-recreate ${{ env.CONTAINER_NAME }}

            # Verify
            sleep 10
            docker compose ps ${{ env.CONTAINER_NAME }}
```

### Infrastructure Deployment

```yaml
# .github/workflows/deploy-infra.yml (in infrastructure repo)
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'config/**'
      - 'templates/**'
  workflow_dispatch:
    inputs:
      profile:
        description: 'Profile to deploy'
        required: true
        default: 'dimosaic'
        type: choice
        options:
          - dimosaic
          - easybiz

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v1

      - name: Install dependencies
        run: bun install

      - name: Set profile
        id: profile
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "profile=${{ inputs.profile }}" >> $GITHUB_OUTPUT
          else
            echo "profile=dimosaic" >> $GITHUB_OUTPUT
          fi

      - name: Deploy
        run: |
          bun run vps deploy \
            --host ${{ secrets.VPS_HOST }} \
            --profile ${{ steps.profile.outputs.profile }} \
            --yes
        env:
          VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}

      - name: Validate
        run: |
          bun run vps validate \
            --host ${{ secrets.VPS_HOST }} \
            --profile ${{ steps.profile.outputs.profile }}
        env:
          VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
```

### Required GitHub Secrets

Set these secrets in each repository:

| Secret | Description |
|--------|-------------|
| `VPS_HOST` | VPS IP address (e.g., `203.0.113.50`) |
| `VPS_SSH_KEY` | SSH private key for `app` user |
| `GHCR_TOKEN` | GitHub PAT with `packages:read` scope (for private images) |
| `SOPS_AGE_KEY` | Age private key for decrypting secrets (infrastructure repo only) |

### Deployment Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CI/CD DEPLOYMENT FLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  FRONTEND REPOS                   BACKEND REPOS                      │
│  ─────────────                   ─────────────                      │
│  [push to main]                  [push to main]                     │
│        │                               │                             │
│        ▼                               ▼                             │
│  ┌──────────┐                   ┌──────────────┐                    │
│  │  Build   │                   │ Build Docker │                    │
│  │  (Bun)   │                   │   (Buildx)   │                    │
│  └────┬─────┘                   └──────┬───────┘                    │
│       │                                │                             │
│       ▼                                ▼                             │
│  ┌──────────┐                   ┌──────────────┐                    │
│  │   SCP    │                   │  Push GHCR   │                    │
│  │ to VPS   │                   │  (ARM64)     │                    │
│  └────┬─────┘                   └──────┬───────┘                    │
│       │                                │                             │
│       ▼                                ▼                             │
│  ┌─────────────────────────────────────────────┐                    │
│  │                    VPS                        │                    │
│  │  ┌─────────────┐    ┌────────────────────┐   │                    │
│  │  │ /var/www/   │    │ docker compose     │   │                    │
│  │  │ app1/       │    │ pull & recreate    │   │                    │
│  │  │ app2/       │    │ container          │   │                    │
│  │  └─────────────┘    └────────────────────┘   │                    │
│  │         │                    │                │                    │
│  │         └──────────┬─────────┘                │                    │
│  │                    ▼                          │                    │
│  │              ┌──────────┐                     │                    │
│  │              │  Caddy   │                     │                    │
│  │              │ (routes) │                     │                    │
│  │              └──────────┘                     │                    │
│  └─────────────────────────────────────────────┘                    │
│                                                                      │
│  INFRASTRUCTURE REPO                                                 │
│  ───────────────────                                                │
│  [push to main] ──▶ vps deploy --profile <name> ──▶ Update all     │
│                                                       services      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```
