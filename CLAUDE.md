# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **requirements/specification repository** for a TypeScript/Bun-based VPS automation system. The system provisions and manages VPS infrastructure with:
- Profile-based multi-domain configuration
- Docker-based services (Caddy, PostgreSQL, Redis, Zitadel, Windmill)
- Host-level services (Mox email server)
- Automated certificate sync between Caddy and Mox
- SOPS/age encrypted secrets

**Current state**: Requirements documentation only - implementation not yet started.

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | TypeScript + Bun | Fast execution, built-in test runner, no transpilation |
| Secrets | SOPS + age | Encrypted in git, no external dependencies |
| Config | YAML with profiles | Human-readable, multi-VPS support |
| Container | Docker Compose | Mature ecosystem |

## Architecture

### Configuration Structure (Planned)
```
config/
├── base.yaml              # Infrastructure service definitions
├── profiles/<name>.yaml   # Per-VPS settings (domains, apps, resources)
└── secrets/<name>.enc.yaml # Encrypted secrets per profile
```

### Project Structure (Planned)
```
src/
├── cli/commands/     # CLI commands (provision, deploy, validate, etc.)
├── core/             # Config loading, secrets, SSH, state tracking
├── provisioners/     # System, Docker, and host service provisioners
├── services/         # Service registry and handlers
├── generators/       # docker-compose.yml, Caddyfile, init-db.sh generators
├── validators/       # Health checks, log analysis, cert validation
├── sync/             # Certificate sync between Caddy and Mox
└── monitor/          # Health monitoring daemon
```

## Commands (When Implemented)

```bash
# Development
bun run src/index.ts              # Run CLI
bun test                          # All tests
bun test tests/unit               # Unit tests only
bun test tests/integration        # Integration tests
bun test --coverage               # With coverage

# CLI commands (future)
vps provision --host <ip> --profile <name>   # Full provisioning
vps deploy --host <ip> --profile <name>      # Deploy changes
vps validate --host <ip>                      # Health checks
vps cert-sync --host <ip>                     # Sync certs to Mox
vps status --host <ip>                        # Current status
```

## Core Concepts

### Profile Merging
Configuration merges: base.yaml + profiles/<name>.yaml + secrets/<name>.enc.yaml -> final config

### Service Categories
- **core**: Infrastructure (Caddy, PostgreSQL, PgBouncer, Redis)
- **apps**: Platform services (Zitadel, Windmill, Postfix relay)
- **host**: Non-Docker services (Mox email server)

### Idempotency
All operations check current state before acting - safe to run multiple times.

### State Tracking
Deployment state stored on server at `/home/app/docker/.vps-state/` for rollback capability.

## Dependencies (Planned)

Key libraries:
- `commander` - CLI framework
- `node-ssh` - SSH/SFTP operations
- `yaml` + `ajv` - Config parsing and validation
- `handlebars` - Template rendering
- `pino` - Structured logging

## Target Environment

- Ubuntu 22.04 LTS or later
- Netcup ARM G11 VPS (16GB RAM, 10 cores, 512GB SSD)
- Docker with Compose plugin
