# Windmill Configuration Reference

## Architecture

```
                    ┌─────────────┐
Internet → Caddy →  │   Server    │ (API + Frontend, port 8000)
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐  ┌────────┐  ┌────────┐
         │ Worker │  │ Worker │  │  LSP   │
         └────┬───┘  └────┬───┘  └────────┘
              │           │
              └─────┬─────┘
                    ▼
              ┌──────────┐
              │PostgreSQL│
              └──────────┘
```

## Core Components

| Service | Purpose | Port |
|---------|---------|------|
| windmill-server | API and frontend | 8000 |
| windmill-worker | Job execution | - |
| windmill-lsp | Editor intellisense | 3001 |
| postgres | State and job queue | 5432 |
| redis | (optional) Job queue | 6379 |

## Environment Variables

### Required

```bash
# Database connection
DATABASE_URL=postgres://windmill:password@postgres:5432/windmill

# Base URL for the instance
WM_BASE_URL=https://windmill.example.com
```

### Server Configuration

```bash
# Number of workers (server-side)
NUM_WORKERS=0  # Set to 0 when using separate worker containers

# Metrics endpoint
METRICS_ADDR=0.0.0.0:8001

# License key (Enterprise)
LICENSE_KEY=<key>
```

### Worker Configuration

```bash
# Worker group (for routing jobs)
WORKER_GROUP=default

# Worker tags (comma-separated)
WORKER_TAGS=deno,python,go,bash,powershell,nativets,bun,php

# Number of parallel jobs per worker
NUM_WORKERS=1

# Job timeout (seconds)
TIMEOUT_WAIT_RESULT=10800  # 3 hours default
```

### Security

```bash
# Enable PID namespace isolation
ENABLE_UNSHARE_PID=true

# NSJAIL sandboxing (requires -nsjail image)
# Provides filesystem isolation
```

## Docker Compose Configuration

### Server Service

```yaml
windmill-server:
  image: ghcr.io/windmill-labs/windmill:main
  restart: unless-stopped
  environment:
    - DATABASE_URL=${DATABASE_URL}
    - MODE=server
    - METRICS_ADDR=0.0.0.0:8001
  ports:
    - "8000:8000"
  networks:
    - windmill-internal
    - web
  depends_on:
    postgres:
      condition: service_healthy
  mem_limit: 1g
  cpus: 1.0
```

### Worker Service

```yaml
windmill-worker:
  image: ghcr.io/windmill-labs/windmill:main
  restart: unless-stopped
  environment:
    - DATABASE_URL=${DATABASE_URL}
    - MODE=worker
    - WORKER_GROUP=default
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - worker-cache:/tmp/windmill/cache
  networks:
    - windmill-internal
  depends_on:
    windmill-server:
      condition: service_healthy
  mem_limit: 1.5g
  cpus: 1.0
  deploy:
    replicas: 2
```

### LSP Service

```yaml
windmill-lsp:
  image: ghcr.io/windmill-labs/windmill-lsp:main
  restart: unless-stopped
  volumes:
    - lsp-cache:/root/.cache
  networks:
    - windmill-internal
  mem_limit: 512m
  cpus: 0.5
```

## Database Setup

### PostgreSQL Initialization

```sql
CREATE DATABASE windmill;
CREATE USER windmill WITH ENCRYPTED PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE windmill TO windmill;

-- For managed databases (non-superuser)
GRANT windmill_admin TO windmill;
GRANT windmill_user TO windmill;
```

### Connection Pool Settings

Recommended for production:
```
max_connections = 100
shared_buffers = 256MB
work_mem = 8MB
```

## Resource Guidelines

| Component | Memory | CPU | Notes |
|-----------|--------|-----|-------|
| Server | 1GB | 1.0 | Handles API/frontend |
| Worker | 1.5GB | 1.0 | Per worker instance |
| LSP | 512MB | 0.5 | Editor support |
| PostgreSQL | 2GB | 1.5 | State storage |

**Scaling rule**: 1 worker per 1 vCPU and 1-2 GB RAM

## Caddy Configuration

```caddyfile
windmill.example.com {
    encode gzip

    # WebSocket support for real-time updates
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websockets windmill-server:8000

    # Regular traffic
    reverse_proxy windmill-server:8000
}
```

## First-Time Setup

1. Access `https://windmill.example.com`
2. Login: `admin@windmill.dev` / `changeme`
3. Go to Instance Settings
4. Configure domain and email settings
5. Create workspace

## Official Documentation

- Self-Hosting: https://www.windmill.dev/docs/advanced/self_host
- Configuration: https://www.windmill.dev/docs/core_concepts/configuration
- Workers: https://www.windmill.dev/docs/core_concepts/worker_groups
