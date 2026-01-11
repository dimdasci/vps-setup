# VPS Automation System Requirements

## Overview

This document set describes the requirements for a TypeScript/Bun-based automation system to provision and manage VPS infrastructure. The system is **domain-agnostic** and supports multiple VPS deployments (e.g., personal projects, business products) with separate configurations.

Key capabilities:
- Reproducible server setup from bare Ubuntu
- Profile-based multi-domain configuration
- Custom application deployment (frontend SPAs, backend APIs)
- GitHub Actions CI/CD integration
- Automated health monitoring and alerting
- Automated DNS record management via Netcup API

## Problem Statement

Manual VPS setup is error-prone and time-consuming:
- Docker Compose manages containerized services, but initial setup requires manual steps
- Mox email server runs on the host (not Docker) and needs separate provisioning
- Certificate sync between Caddy and Mox requires manual intervention
- No automated way to validate that all services are healthy
- Adding/removing services requires editing multiple files
- Deploying custom applications requires manual Docker and Caddy configuration

## Solution

A CLI-based automation tool written in TypeScript (running on Bun) that:
1. **Provisions** a bare Ubuntu VPS to a fully running state
2. **Deploys** configuration changes with idempotent operations
3. **Validates** service health after deployment
4. **Monitors** ongoing health and sends alerts
5. **Syncs** certificates from Caddy to Mox automatically
6. **Supports multiple domains** per VPS with profile-based configuration
7. **Integrates with GitHub Actions** for CI/CD of custom applications

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | TypeScript + Bun | Readable, type-safe, fast execution, no transpilation |
| Container Runtime | Docker | Mature ecosystem, simple licensing on Linux servers |
| Trigger | CLI + GitHub Actions | Manual control for infra, automated for apps |
| Secrets | SOPS + age | Encrypted in git, no external service dependency |
| Config | YAML with profiles | Human-readable, easy to diff, multi-VPS support |
| DB Pooling | PgBouncer | Connection management for multiple apps |
| Monitoring | Lightweight daemon | Resource-efficient health checks and alerting |

## Documents

| Document | Description |
|----------|-------------|
| [architecture.md](./architecture.md) | System architecture, project structure, TypeScript types |
| [configuration.md](./configuration.md) | Service config schema, secrets format |
| [workflows.md](./workflows.md) | Provisioning, deployment, and validation workflows |
| [certificate-sync.md](./certificate-sync.md) | Caddy to Mox certificate synchronization |
| [cli-reference.md](./cli-reference.md) | CLI commands and options |
| [testing.md](./testing.md) | Testing strategy |
| [monitoring.md](./monitoring.md) | Health monitoring and alerting |
| [skills-and-tools.md](./skills-and-tools.md) | Required skills and recommended libraries |

## Quick Start (Future Usage)

Once implemented, the typical workflow will be:

```bash
# Initial setup on a new VPS (using a profile)
vps provision --host <ip> --user root --profile dimosaic

# Deploy infrastructure changes
vps deploy --host <ip> --profile dimosaic

# Validate all services are healthy
vps validate --host <ip> --profile dimosaic

# Sync certificates to Mox
vps cert-sync --host <ip>

# Check current status
vps status --host <ip>
```

### Multi-VPS Deployment

```bash
# Personal VPS (dimosaic.com + side projects)
vps deploy --host 1.2.3.4 --profile dimosaic

# Business VPS (easybiz.io)
vps deploy --host 5.6.7.8 --profile easybiz
```

### Application CI/CD

Applications deploy via GitHub Actions (see [workflows.md](./workflows.md#4-cicd-workflows-github-actions)):
- **Frontend apps**: Built with Bun, SCP to `/var/www/<app>/`
- **Backend APIs**: Docker images pushed to GHCR, pulled by VPS

## Infrastructure Services

The automation provisions and manages these services:

**Core Infrastructure (Docker):**
- Caddy (reverse proxy, automatic SSL for all domains)
- PostgreSQL 16 (shared database)
- PgBouncer (connection pooling)
- Redis (shared cache)

**Platform Services (Docker):**
- Zitadel + Zitadel-Login (identity provider)
- Windmill Server + Workers + LSP (workflow engine)
- Postfix Relay (internal SMTP)

**Host Services:**
- Mox (full email server)

**Custom Applications (per profile):**
- Static frontends (served by Caddy)
- Container backends (managed by Docker Compose)

## DNS Automation (Netcup)

The automation includes DNS record management via Netcup DNS API:
- **A/AAAA records**: Create/update for app subdomains
- **Email records**: MX, SPF, DKIM, DMARC, MTA-STS
- **Validation**: Verify DNS propagation before service deployment
- **Multi-domain**: Support domains from external registrars (NS → Netcup)

Netcup DNS limitations:
- No per-record TTL (zone-wide only)
- Slow propagation (~15 minutes typical)
- API requires full zone updates (not individual record CRUD)

## Resource Constraints

The target VPS is Netcup ARM G11:
- 16GB RAM
- 10 CPU cores
- 512GB SSD

Typical allocation:
- Infrastructure services: ~8GB RAM
- Custom applications: ~4GB RAM (2-5 APIs + frontends)
- Headroom: ~4GB RAM

## Out of Scope

The following are explicitly out of scope:
- Multi-environment support (dev/staging/prod on same VPS)
- Full observability stack (Prometheus/Grafana)
- Kubernetes migration
- API Gateway (Caddy handles routing; add KrakenD later if needed)
