# CLI Reference

## Overview

The `vps` CLI provides commands for provisioning, deploying, validating, and managing the VPS infrastructure.

```bash
vps <command> [options]
```

## Global Options

These options are available for all commands:

| Option | Short | Description |
|--------|-------|-------------|
| `--host <ip>` | `-h` | Target server IP or hostname (required) |
| `--profile <name>` | `-p` | Profile name (e.g., dimosaic, easybiz) |
| `--user <user>` | `-u` | SSH username (default varies by command) |
| `--key <path>` | `-k` | SSH private key path (default: ~/.ssh/id_rsa) |
| `--base <path>` | `-b` | Base config file (default: ./config/base.yaml) |
| `--verbose` | `-v` | Enable detailed output |
| `--quiet` | `-q` | Suppress non-error output |
| `--dry-run` | | Show what would be done without executing |
| `--help` | | Show help for command |

### Profile Resolution

When `--profile <name>` is specified:
- Profile config: `./config/profiles/<name>.yaml`
- Secrets file: `./config/secrets/<name>.enc.yaml`

Profile can also be set via environment variable:
```bash
export VPS_PROFILE=dimosaic
vps deploy --host 1.2.3.4  # Uses dimosaic profile
```

## Commands

### vps provision

Full provisioning of a bare Ubuntu VPS.

```bash
vps provision --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: root, requires root for initial setup) |
| `--step <step>` | Start from specific step (useful for resuming failed provision) |
| `--skip-mox` | Skip Mox email server installation |
| `--skip-firewall` | Skip UFW firewall configuration |
| `--yes` | Skip confirmation prompts |

**Steps:**

1. `preflight` - System checks
2. `system` - Package installation
3. `users` - Create app and mox users
4. `firewall` - Configure UFW
5. `docker` - Install Docker
6. `mox` - Install Mox email server
7. `docker-env` - Set up Docker environment
8. `deploy` - Deploy Docker services
9. `cert-sync` - Sync certificates to Mox
10. `validate` - Run health checks

**Examples:**

```bash
# Full provisioning with profile
vps provision --host 203.0.113.50 --user root --profile dimosaic

# Resume from specific step
vps provision --host 203.0.113.50 --profile dimosaic --step docker-env

# Without Mox (Docker services only)
vps provision --host 203.0.113.50 --profile dimosaic --skip-mox

# Dry run
vps provision --host 203.0.113.50 --profile dimosaic --dry-run
```

---

### vps deploy

Deploy configuration changes to an existing installation.

```bash
vps deploy --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--service <name>` | Deploy only specific service |
| `--pull` | Pull latest images before deploying |
| `--build` | Rebuild custom images (e.g., windmill-worker) |
| `--no-restart` | Apply config changes without restarting services |
| `--yes` | Skip confirmation prompts |

**Examples:**

```bash
# Deploy all configuration changes with profile
vps deploy --host 203.0.113.50 --profile dimosaic

# Deploy with image updates
vps deploy --host 203.0.113.50 --profile dimosaic --pull

# Deploy single service
vps deploy --host 203.0.113.50 --profile dimosaic --service zitadel

# Deploy custom app only
vps deploy --host 203.0.113.50 --profile dimosaic --service personal-api

# Rebuild custom images
vps deploy --host 203.0.113.50 --profile dimosaic --build

# Dry run (show diff only)
vps deploy --host 203.0.113.50 --profile dimosaic --dry-run

# Using environment variable for profile
VPS_PROFILE=easybiz vps deploy --host 5.6.7.8 --pull
```

**Output:**

```
Deployment Plan
===============

Configuration Diff:
  docker-compose.yml:
    services.windmill-server.resources:
-     memory: "512m"
+     memory: "768m"

  Caddyfile:
    No changes

Actions:
  1. Update docker-compose.yml
  2. Recreate windmill-server container

Proceed? [y/N] y

Deploying...
  [✓] Updated configuration files
  [✓] Recreating windmill-server container
  [✓] Health check passed

Deployment completed successfully.
```

---

### vps validate

Run health checks and validation.

```bash
vps validate --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--service <name>` | Validate specific service only |
| `--category <cat>` | Validate category only (infrastructure, container, endpoint, certificate, logs) |
| `--output <format>` | Output format: text, json, html (default: text) |
| `--fail-fast` | Stop on first failure |

**Examples:**

```bash
# Full validation
vps validate --host 203.0.113.50

# Validate specific service
vps validate --host 203.0.113.50 --service postgres

# Validate only endpoints
vps validate --host 203.0.113.50 --category endpoint

# JSON output for scripting
vps validate --host 203.0.113.50 --output json

# Verbose output (show all checks)
vps validate --host 203.0.113.50 --verbose
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |
| 2 | Configuration or connection error |

---

### vps status

Show current deployment status.

```bash
vps status --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--output <format>` | Output format: text, json (default: text) |
| `--watch` | Continuous monitoring (refresh every 5s) |

**Examples:**

```bash
# Show status
vps status --host 203.0.113.50

# JSON output
vps status --host 203.0.113.50 --output json

# Watch mode
vps status --host 203.0.113.50 --watch
```

**Output:**

```
VPS Status: 203.0.113.50
========================

System:
  Uptime: 15 days, 3 hours
  Memory: 8.6 GB / 12 GB (72%)
  Disk:   42 GB / 194 GB (22%)
  Load:   0.45, 0.52, 0.48

Docker Services:
  NAME              STATUS    HEALTH    UPTIME
  caddy             running   healthy   15d
  postgres          running   healthy   15d
  redis             running   healthy   15d
  zitadel           running   healthy   15d
  zitadel-login     running   healthy   15d
  windmill-server   running   healthy   15d
  windmill-worker   running   -         15d (2 replicas)
  windmill-lsp      running   -         15d
  postfix-relay     running   -         15d

Host Services:
  NAME    STATUS    UPTIME
  mox     active    15d

Last Deployment: 2025-01-09T10:30:00Z (2 hours ago)
Config Version: abc123
```

---

### vps secrets

Manage encrypted secrets.

```bash
vps secrets <subcommand> [options]
```

**Subcommands:**

#### vps secrets init

Create initial secrets file with generated passwords.

```bash
vps secrets init [options]
```

| Option | Description |
|--------|-------------|
| `--output <path>` | Output file path (default: ./config/secrets.yaml) |
| `--encrypt` | Encrypt after generation |

#### vps secrets edit

Decrypt, edit, and re-encrypt secrets file.

```bash
vps secrets edit [options]
```

| Option | Description |
|--------|-------------|
| `--file <path>` | Secrets file path |
| `--editor <cmd>` | Editor command (default: $EDITOR or vim) |

#### vps secrets view

Decrypt and display secrets (for verification).

```bash
vps secrets view [options]
```

| Option | Description |
|--------|-------------|
| `--file <path>` | Secrets file path |
| `--key <name>` | Show specific secret only (e.g., postgres.root_password) |

#### vps secrets rotate

Generate new passwords for specified secrets.

```bash
vps secrets rotate [options]
```

| Option | Description |
|--------|-------------|
| `--file <path>` | Secrets file path |
| `--key <name>` | Rotate specific secret only |
| `--all` | Rotate all secrets |
| `--deploy` | Deploy changes immediately after rotation |

**Examples:**

```bash
# Initialize new secrets file
vps secrets init --output config/secrets.yaml --encrypt

# Edit secrets
vps secrets edit --file config/secrets.enc.yaml

# View specific secret
vps secrets view --key postgres.root_password

# Rotate database passwords
vps secrets rotate --key postgres.root_password --deploy
```

---

### vps cert-sync

Synchronize certificates from Caddy to Mox.

```bash
vps cert-sync --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: root, needs to write to /home/mox) |
| `--domain <domain>` | Specific domain to sync (default: mail.<global.domain>) |
| `--force` | Sync even if certificates match |

**Examples:**

```bash
# Sync certificates
vps cert-sync --host 203.0.113.50

# Force sync
vps cert-sync --host 203.0.113.50 --force

# Dry run
vps cert-sync --host 203.0.113.50 --dry-run
```

**Output:**

```
Certificate Sync
================

Source: Caddy (Docker)
  Path: /data/caddy/certificates/.../mail.fidudoc.eu/
  Expires: 2025-04-09 (67 days)
  Hash: a1b2c3d4...

Target: Mox (/home/mox/certs/)
  Current Hash: a1b2c3d4...

Status: UP-TO-DATE (hashes match)
```

---

### vps rollback

Rollback to a previous deployment state.

```bash
vps rollback --host <ip> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--list` | List available rollback points |
| `--version <timestamp>` | Rollback to specific version |
| `--yes` | Skip confirmation |

**Examples:**

```bash
# List rollback points
vps rollback --host 203.0.113.50 --list

# Rollback to specific version
vps rollback --host 203.0.113.50 --version 2025-01-08T15:45:00

# Rollback to previous version
vps rollback --host 203.0.113.50
```

**Output:**

```
Available Rollback Points
=========================

  VERSION                 AGE          CHANGES
  2025-01-09T10:30:00    2 hours      windmill memory update
  2025-01-08T15:45:00    1 day        Added grafana service
  2025-01-07T09:00:00    2 days       Initial deployment

Select version [2025-01-09T10:30:00]:
```

---

### vps logs

View service logs.

```bash
vps logs --host <ip> [options] [service]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--follow` / `-f` | Follow log output |
| `--tail <n>` | Number of lines to show (default: 100) |
| `--since <time>` | Show logs since timestamp or duration (e.g., "1h", "2025-01-09") |
| `--grep <pattern>` | Filter logs by pattern |

**Examples:**

```bash
# View all logs
vps logs --host 203.0.113.50

# Follow specific service
vps logs --host 203.0.113.50 -f zitadel

# Last 50 lines with grep
vps logs --host 203.0.113.50 --tail 50 --grep error postgres

# Mox logs (host service)
vps logs --host 203.0.113.50 mox

# Logs since 1 hour ago
vps logs --host 203.0.113.50 --since 1h
```

---

### vps exec

Execute command on server (convenience wrapper).

```bash
vps exec --host <ip> [options] -- <command>
```

**Options:**

| Option | Description |
|--------|-------------|
| `--user <user>` | SSH user (default: app) |
| `--service <name>` | Execute inside Docker container |
| `--tty` / `-t` | Allocate pseudo-TTY |

**Examples:**

```bash
# Run command on server
vps exec --host 203.0.113.50 -- df -h

# Execute inside container
vps exec --host 203.0.113.50 --service postgres -- psql -U postgres

# Interactive shell in container
vps exec --host 203.0.113.50 --service windmill-server -t -- /bin/sh
```

---

### vps dns

Manage DNS records via Netcup DNS API.

```bash
vps dns <subcommand> [options]
```

**Subcommands:**

#### vps dns status

Show current DNS records for configured zones.

```bash
vps dns status [options]
```

| Option | Description |
|--------|-------------|
| `--zone <domain>` | Specific zone to show (default: all) |
| `--output <format>` | Output format: text, json (default: text) |

#### vps dns sync

Synchronize DNS records based on configuration.

```bash
vps dns sync [options]
```

| Option | Description |
|--------|-------------|
| `--zone <domain>` | Specific zone to sync (default: all) |
| `--dry-run` | Show changes without applying |
| `--yes` | Apply changes without confirmation |
| `--wait` | Wait for DNS propagation after sync |
| `--timeout <seconds>` | Propagation timeout (default: 900) |

#### vps dns validate

Validate DNS records are correctly propagated.

```bash
vps dns validate [options]
```

| Option | Description |
|--------|-------------|
| `--zone <domain>` | Specific zone to validate |
| `--timeout <seconds>` | Propagation timeout (default: 900) |
| `--record-type <type>` | Validate specific record type only (A, MX, TXT, etc.) |

#### vps dns add

Add a DNS record manually.

```bash
vps dns add <zone> <type> <hostname> <value> [options]
```

| Option | Description |
|--------|-------------|
| `--priority <n>` | Priority for MX records |

#### vps dns remove

Remove a DNS record.

```bash
vps dns remove <zone> <type> <hostname> [options]
```

| Option | Description |
|--------|-------------|
| `--yes` | Remove without confirmation |

**Examples:**

```bash
# Show all DNS records
vps dns status --profile dimosaic

# Show specific zone
vps dns status --zone dimosaic.com

# Dry-run sync to see what would change
vps dns sync --profile dimosaic --dry-run

# Sync and wait for propagation
vps dns sync --profile dimosaic --wait

# Validate MX records are propagated
vps dns validate --zone dimosaic.com --record-type MX

# Add A record for new subdomain
vps dns add dimosaic.com A newapp 203.0.113.50

# Remove old record
vps dns remove dimosaic.com A oldapp --yes
```

**Output:**

```
DNS Status: dimosaic.com
========================

A Records:
  @          → 203.0.113.50
  mail       → 203.0.113.50
  mta-sts    → 203.0.113.50
  autoconfig → 203.0.113.50
  api        → 203.0.113.50
  app        → 203.0.113.50

MX Records:
  @          → mail.dimosaic.com (priority: 10)

TXT Records:
  @          → v=spf1 mx ~all
  _dmarc     → v=DMARC1; p=quarantine; rua=mailto:dmarcreports@dimosaic.com
  _mta-sts   → v=STSv1; id=1
  <selector>._domainkey → v=DKIM1; k=rsa; p=...

Last Sync: 2025-01-09T10:30:00Z
```

**Sync Output:**

```
DNS Sync: dimosaic.com
======================

Changes:
  + A     newapp     203.0.113.50
  ~ TXT   _dmarc     v=DMARC1; p=reject; ...  (was: p=quarantine)
  - A     oldapp     203.0.113.50

Apply changes? [y/N] y

Applying changes...
  [✓] Updated zone records
  [·] Waiting for propagation (timeout: 15m)...
  [✓] All records propagated

DNS sync completed.
```

---

## Configuration File

The CLI uses `~/.vpsrc` or `./.vpsrc` for defaults:

```yaml
# ~/.vpsrc
defaults:
  user: app
  key: ~/.ssh/vps_key
  base: ./config/base.yaml

# Profile-to-host mappings
profiles:
  dimosaic:
    host: 1.2.3.4
    description: "Personal VPS"

  easybiz:
    host: 5.6.7.8
    description: "Business VPS"
```

Use profiles:

```bash
# Host is automatically resolved from profile
vps deploy --profile dimosaic

# Or specify both explicitly
vps deploy --host 1.2.3.4 --profile dimosaic
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `VPS_HOST` | Default host (overrides profile) |
| `VPS_PROFILE` | Default profile name |
| `VPS_USER` | Default SSH user |
| `VPS_KEY` | Default SSH key path |
| `VPS_BASE` | Default base config file path |
| `SOPS_AGE_KEY_FILE` | Path to age key file for SOPS |
| `SOPS_AGE_KEY` | Age private key content (for CI/CD) |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Operation failed |
| 2 | Configuration error |
| 3 | Connection error |
| 4 | Validation error |
| 130 | Interrupted (Ctrl+C) |

---

## Shell Completion

Generate shell completion scripts:

```bash
# Bash
vps completion bash > /etc/bash_completion.d/vps

# Zsh
vps completion zsh > ~/.zsh/completion/_vps

# Fish
vps completion fish > ~/.config/fish/completions/vps.fish
```
