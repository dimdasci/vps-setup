# Configuration Schema

## Overview

Configuration is split into multiple files:
1. **base.yaml** - Shared infrastructure service definitions
2. **profiles/<name>.yaml** - Per-VPS configuration (domains, apps, resource tuning)
3. **secrets/<name>.enc.yaml** - Encrypted secrets per profile

## Directory Structure

```
config/
├── base.yaml                 # Infrastructure services (Caddy, PostgreSQL, etc.)
├── profiles/
│   ├── dimosaic.yaml        # Personal VPS profile
│   └── easybiz.yaml         # Business VPS profile
└── secrets/
    ├── dimosaic.enc.yaml    # Secrets for dimosaic
    └── easybiz.enc.yaml     # Secrets for easybiz
```

## Profile Configuration

### Example Profile: dimosaic.yaml

```yaml
# config/profiles/dimosaic.yaml
version: "1.0"

# ============================================
# PROFILE METADATA
# ============================================
profile:
  name: dimosaic
  description: "Personal VPS for dimosaic.com and side projects"

# ============================================
# GLOBAL SETTINGS
# ============================================
global:
  primary_domain: dimosaic.com      # Infrastructure services use this
  timezone: Europe/Brussels
  admin_email: admin@dimosaic.com

  docker:
    compose_version: "3.8"
    network_subnet: "172.21.0.0/16"

# ============================================
# DOMAINS SERVED BY THIS VPS
# ============================================
domains:
  # Primary domain
  dimosaic.com:
    description: "Personal brand and projects"
    apps:
      - name: personal-site
        subdomain: ""                 # Root domain
        type: static
        path: /var/www/dimosaic

      - name: personal-api
        subdomain: api
        type: container
        image: ghcr.io/dimosaic/personal-api:latest
        port: 3000
        environment:
          NODE_ENV: production
          DATABASE_URL: "postgresql://personal_api:{{ secrets.apps.personal_api.db_password }}@pgbouncer:6432/personal_api"
          REDIS_URL: "redis://redis:6379"
        resources:
          memory: 512m
          cpus: "0.5"

  # Additional domain for a side project
  newproduct.io:
    description: "Side project product"
    apps:
      - name: newproduct-landing
        subdomain: ""                 # Root domain
        type: static
        path: /var/www/newproduct

      - name: newproduct-app
        subdomain: app
        type: container
        image: ghcr.io/dimosaic/newproduct-app:latest
        port: 3001
        environment:
          NODE_ENV: production
          API_URL: "https://api.newproduct.io"
        resources:
          memory: 256m
          cpus: "0.25"

      - name: newproduct-api
        subdomain: api
        type: container
        image: ghcr.io/dimosaic/newproduct-api:latest
        port: 3002
        environment:
          NODE_ENV: production
          DATABASE_URL: "postgresql://newproduct:{{ secrets.apps.newproduct.db_password }}@pgbouncer:6432/newproduct"
          REDIS_URL: "redis://redis:6379"
        healthcheck:
          type: http
          path: /health
          port: 3002
        resources:
          memory: 512m
          cpus: "0.5"

# ============================================
# RESOURCE OVERRIDES (optional)
# ============================================
resources:
  # Override base.yaml resource limits for this VPS
  postgres:
    memory: 3g
    cpus: "2.0"
  windmill-worker:
    replicas: 3
    memory: 2g

# ============================================
# CUSTOM DATABASES
# ============================================
databases:
  - name: personal_api
    user: personal_api
    password_secret: secrets.apps.personal_api.db_password
  - name: newproduct
    user: newproduct
    password_secret: secrets.apps.newproduct.db_password

# ============================================
# DNS CONFIGURATION (Netcup)
# ============================================
dns:
  provider: netcup
  # API credentials referenced from secrets
  customer_number_secret: secrets.dns.customer_number
  api_key_secret: secrets.dns.api_key
  api_password_secret: secrets.dns.api_password

  # Zones managed via Netcup DNS API
  zones:
    # Primary domain (registered at Netcup or NS delegated)
    dimosaic.com:
      type: primary
      auto_records: true    # Auto-create A, MX, SPF, DKIM, DMARC
      ttl: 3600

    # External domain (registered at Netim, NS pointing to Netcup)
    newproduct.io:
      type: external
      registrar: netim      # Informational only
      auto_records: true
      ttl: 3600

  # Global settings
  propagation_timeout: 900  # 15 minutes (Netcup is slow)
  verify_before_deploy: true
```

## Base Configuration

### Full Example: base.yaml

```yaml
# config/base.yaml
version: "1.0"

# ============================================
# GLOBAL DEFAULTS (can be overridden by profile)
# ============================================
global:
  timezone: Europe/Brussels
  docker:
    compose_version: "3.8"
    network_subnet: "172.21.0.0/16"

# ============================================
# SERVICE CATEGORIES
# ============================================
categories:
  core:
    description: "Infrastructure services required by all others"
    start_order: 1
  apps:
    description: "Application services"
    start_order: 2
  host:
    description: "Host-level services (not in Docker)"
    start_order: 0  # Provision before Docker

# ============================================
# SERVICES
# ============================================
services:
  # ------------------------------------------
  # CORE: Caddy Reverse Proxy
  # ------------------------------------------
  caddy:
    enabled: true
    category: core
    type: docker
    image: caddy:2.8-alpine

    # Domain routing (generates Caddyfile)
    domains:
      - domain: "{{ global.domain }}"
        upstream: external
        external_url: "https://application-production-333f.up.railway.app"
      - domain: "www.{{ global.domain }}"
        redirect_to: "{{ global.domain }}"

    ports:
      - host: 80
        container: 80
        protocol: tcp
        expose_external: true
      - host: 443
        container: 443
        protocol: tcp
        expose_external: true

    volumes:
      - name: caddy-data
        path: /data
      - name: caddy-config
        path: /config
      - type: bind
        source: ./Caddyfile
        target: /etc/caddy/Caddyfile
        readonly: true

    networks:
      - web

    resources:
      memory: 256m
      cpus: "0.25"

    healthcheck:
      type: tcp
      port: 80
      interval: 30s
      timeout: 5s
      retries: 3

  # ------------------------------------------
  # CORE: PostgreSQL Database
  # ------------------------------------------
  postgres:
    enabled: true
    category: core
    type: docker
    image: postgres:16

    ports:
      - host: 5432
        container: 5432
        protocol: tcp
        expose_external: true  # Exposed for admin access

    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: "{{ secrets.postgres.root_password }}"
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=en_US.utf8 --lc-ctype=en_US.utf8"

    volumes:
      - name: postgres-data
        path: /var/lib/postgresql/data
      - type: bind
        source: ./init-db.sh
        target: /docker-entrypoint-initdb.d/init-db.sh
        readonly: true
      - type: bind
        source: ./postgresql.conf
        target: /etc/postgresql/postgresql.conf
        readonly: true
      - type: bind
        source: ./pg_hba.conf
        target: /etc/postgresql/pg_hba.conf
        readonly: true

    command:
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - hba_file=/etc/postgresql/pg_hba.conf

    networks:
      - web
      - zitadel-internal
      - windmill-internal

    resources:
      memory: 2g
      cpus: "1.5"

    healthcheck:
      type: command
      command: ["pg_isready", "-h", "localhost", "-U", "postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

    # Databases to create for other services
    databases:
      - name: zitadel
        user: zitadel
        password_secret: secrets.zitadel.db_password
      - name: windmill
        user: windmill_user
        password_secret: secrets.windmill.db_password
        extra_users:
          - name: windmill_admin
            password_secret: secrets.windmill.db_password
            options: "CREATEDB CREATEROLE BYPASSRLS"

  # ------------------------------------------
  # CORE: Redis Cache (Shared)
  # ------------------------------------------
  redis:
    enabled: true
    category: core
    type: docker
    image: redis:7-alpine

    command: "redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru --save 60 1 --loglevel warning"

    volumes:
      - name: redis-data
        path: /data

    networks:
      - web              # Accessible by all services
      - windmill-internal

    resources:
      memory: 512m
      cpus: "0.25"

    healthcheck:
      type: command
      command: ["redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ------------------------------------------
  # CORE: PgBouncer Connection Pooler
  # ------------------------------------------
  pgbouncer:
    enabled: true
    category: core
    type: docker
    image: edoburu/pgbouncer:latest

    depends_on:
      - postgres

    environment:
      DATABASE_URL: "postgres://postgres:{{ secrets.postgres.root_password }}@postgres:5432/postgres"
      POOL_MODE: transaction
      MAX_CLIENT_CONN: "200"
      DEFAULT_POOL_SIZE: "20"
      MIN_POOL_SIZE: "5"
      RESERVE_POOL_SIZE: "5"
      RESERVE_POOL_TIMEOUT: "3"
      SERVER_LIFETIME: "3600"
      SERVER_IDLE_TIMEOUT: "600"
      LOG_CONNECTIONS: "0"
      LOG_DISCONNECTIONS: "0"
      LOG_POOLER_ERRORS: "1"
      STATS_PERIOD: "60"
      # Auth configuration
      AUTH_TYPE: scram-sha-256
      AUTH_FILE: /etc/pgbouncer/userlist.txt

    volumes:
      - type: bind
        source: ./pgbouncer/userlist.txt
        target: /etc/pgbouncer/userlist.txt
        readonly: true

    networks:
      - web              # Apps connect through PgBouncer
      - zitadel-internal
      - windmill-internal

    ports:
      - container: 6432
        internal: true

    resources:
      memory: 64m
      cpus: "0.1"

    healthcheck:
      type: tcp
      port: 6432
      interval: 10s
      timeout: 3s
      retries: 3

  # ------------------------------------------
  # APPS: Zitadel Identity Provider
  # ------------------------------------------
  zitadel:
    enabled: true
    category: apps
    type: docker
    image: ghcr.io/zitadel/zitadel:latest
    domain: "auth.{{ global.domain }}"

    depends_on:
      - postgres

    user: "0"  # Run as root
    command: "start-from-init --masterkeyFromEnv"

    environment:
      ZITADEL_MASTERKEY: "{{ secrets.zitadel.masterkey }}"
      ZITADEL_EXTERNALDOMAIN: "auth.{{ global.domain }}"
      ZITADEL_EXTERNALSECURE: "true"
      ZITADEL_TLS_ENABLED: "false"
      ZITADEL_EXTERNALPORT: "443"
      ZITADEL_DATABASE_POSTGRES_HOST: postgres
      ZITADEL_DATABASE_POSTGRES_PORT: "5432"
      ZITADEL_DATABASE_POSTGRES_DATABASE: zitadel
      ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME: postgres
      ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD: "{{ secrets.postgres.root_password }}"
      ZITADEL_DATABASE_POSTGRES_USER_USERNAME: zitadel
      ZITADEL_DATABASE_POSTGRES_USER_PASSWORD: "{{ secrets.zitadel.db_password }}"
      ZITADEL_FIRSTINSTANCE_ORG_NAME: "{{ secrets.zitadel.org_name }}"
      ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME: "{{ secrets.zitadel.admin_email }}"
      ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD: "{{ secrets.zitadel.admin_password }}"

    volumes:
      - type: bind
        source: ./zitadel-config.yaml
        target: /etc/zitadel/config.yaml
        readonly: true
      - name: zitadel-keys
        path: /etc/zitadel

    networks:
      - web
      - zitadel-internal

    ports:
      - container: 8080
        internal: true

    resources:
      memory: 1g
      cpus: "1.0"

    healthcheck:
      type: command
      command: ["/app/zitadel", "ready"]
      interval: 30s
      timeout: 10s
      retries: 5

    caddy:
      protocol: h2c  # HTTP/2 cleartext
      routes:
        - path: "/ui/v2/login/*"
          upstream: "http://zitadel-login:3000"

  # ------------------------------------------
  # APPS: Zitadel Login UI
  # ------------------------------------------
  zitadel-login:
    enabled: true
    category: apps
    type: docker
    image: ghcr.io/zitadel/zitadel-login:latest

    depends_on:
      - zitadel

    environment:
      ZITADEL_API_URL: "http://zitadel:8080"
      NEXT_PUBLIC_BASE_PATH: "/ui/v2/login"
      PORT: "3000"
      ZITADEL_SERVICE_USER_TOKEN_FILE: /etc/zitadel/login-client.pat

    volumes:
      - name: zitadel-keys
        path: /etc/zitadel
        readonly: true

    networks:
      - web
      - zitadel-internal

    ports:
      - container: 3000
        internal: true

    resources:
      memory: 256m
      cpus: "0.25"

    healthcheck:
      type: http
      path: /healthz
      port: 3000
      internal: true

  # ------------------------------------------
  # APPS: Windmill Server
  # ------------------------------------------
  windmill-server:
    enabled: true
    category: apps
    type: docker
    image: ghcr.io/windmill-labs/windmill:main
    domain: "wm.{{ global.domain }}"

    depends_on:
      - postgres
      - redis

    environment:
      DATABASE_URL: "postgresql://windmill_admin:{{ secrets.windmill.db_password }}@postgres:5432/windmill?sslmode=disable"
      BASE_URL: "https://wm.{{ global.domain }}"
      REDIS_URL: "redis://redis:6379"
      MODE: server

    volumes:
      - name: windmill-server-logs
        path: /tmp/windmill/logs

    networks:
      - web
      - windmill-internal

    ports:
      - container: 8000
        internal: true

    resources:
      memory: 512m
      cpus: "0.5"

    healthcheck:
      type: http
      path: /api/version
      port: 8000
      internal: true

    caddy:
      security_headers: true
      proxy_headers:
        - "X-Real-IP {remote_host}"
        - "X-Forwarded-For {remote_host}"
        - "X-Forwarded-Proto {scheme}"

  # ------------------------------------------
  # APPS: Windmill Workers
  # ------------------------------------------
  windmill-worker:
    enabled: true
    category: apps
    type: docker

    build:
      context: ./windmill-worker
      dockerfile: Dockerfile

    depends_on:
      - windmill-server

    environment:
      DATABASE_URL: "postgresql://windmill_admin:{{ secrets.windmill.db_password }}@postgres:5432/windmill?sslmode=disable"
      BASE_URL: "https://wm.{{ global.domain }}"
      REDIS_URL: "redis://redis:6379"
      MODE: worker
      WORKER_GROUP: default
      WORKER_TAGS: "deno,python3,go,bash,powershell,dependency,flow,hub,other,bun,postgresql,nativets"
      DISABLE_NUSER: "true"

    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
      - name: windmill-worker-cache
        path: /tmp/windmill/cache
      - name: windmill-worker-logs
        path: /tmp/windmill/logs

    networks:
      - windmill-internal

    replicas: 2

    resources:
      memory: 1.5g
      cpus: "1.0"

    healthcheck:
      type: logs
      pattern: "worker .* started"
      timeout: 60s

  # ------------------------------------------
  # APPS: Windmill LSP
  # ------------------------------------------
  windmill-lsp:
    enabled: true
    category: apps
    type: docker
    image: ghcr.io/windmill-labs/windmill-lsp:latest

    depends_on:
      - windmill-server

    volumes:
      - name: windmill-lsp-cache
        path: /root/.cache

    networks:
      - windmill-internal

    resources:
      memory: 256m
      cpus: "0.25"

  # ------------------------------------------
  # APPS: Postfix SMTP Relay
  # ------------------------------------------
  postfix-relay:
    enabled: true
    category: apps
    type: docker
    image: boky/postfix:latest

    environment:
      ALLOWED_SENDER_DOMAINS: "{{ global.domain }}"
      RELAYHOST: "[172.23.0.1]:587"
      RELAYHOST_USERNAME: "noreply@{{ global.domain }}"
      RELAYHOST_PASSWORD: "{{ secrets.postfix.smtp_password }}"
      DISABLE_SMTP_AUTH_ON_PORT_25: "true"

    networks:
      - web

    resources:
      memory: 256m
      cpus: "0.25"

  # ------------------------------------------
  # HOST: Mox Email Server
  # ------------------------------------------
  mox:
    enabled: true
    category: host
    type: host  # Not in Docker
    domain: "mail.{{ global.domain }}"

    additional_domains:
      - "mta-sts.{{ global.domain }}"
      - "autoconfig.{{ global.domain }}"

    user: mox
    home: /home/mox

    # External ports
    ports:
      - host: 25
        protocol: tcp
        description: "SMTP - Incoming Mail"
      - host: 465
        protocol: tcp
        description: "SMTP Submissions - Encrypted"
      - host: 587
        protocol: tcp
        description: "SMTP Submission"
      - host: 993
        protocol: tcp
        description: "IMAPS - Encrypted"

    # Internal ports (for Caddy proxy)
    internal_ports:
      - port: 8080
        listen: "127.0.0.1,172.16.0.0/12"
        description: "Admin/Webmail interface"

    # Certificate sync from Caddy
    certificates:
      source: caddy
      domains:
        - "mail.{{ global.domain }}"
      target_path: /home/mox/certs

    systemd:
      service_name: mox
      type: notify

    healthcheck:
      type: systemd
      service: mox
      ports:
        - 25
        - 465
        - 993

    # Caddy configuration for admin/webmail proxy
    caddy:
      routes:
        - path: "/admin/*"
          upstream: "http://host.docker.internal:8080"
          header_up_host: localhost
        - path: "/*"
          upstream: "http://host.docker.internal:8080"

# ============================================
# DOCKER NETWORKS
# ============================================
networks:
  web:
    driver: bridge
  zitadel-internal:
    driver: bridge
  windmill-internal:
    driver: bridge
```

## Secrets Configuration

### SOPS Configuration (.sops.yaml)

```yaml
# .sops.yaml
creation_rules:
  # Profile-specific secrets
  - path_regex: secrets/dimosaic\.yaml$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: secrets/easybiz\.yaml$
    age: >-
      age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

### Secrets Template (before encryption)

```yaml
# config/secrets/dimosaic.yaml (encrypt with: sops -e dimosaic.yaml > dimosaic.enc.yaml)

# ============================================
# INFRASTRUCTURE SECRETS
# ============================================

# PostgreSQL root credentials
postgres:
  root_password: "generate-secure-password-here"

# Zitadel identity provider
zitadel:
  db_password: "generate-secure-password-here"
  masterkey: "32-character-random-string-here!"
  org_name: "Dimosaic"
  admin_email: "admin@dimosaic.com"
  admin_password: "secure-admin-password-here"

# Windmill workflow engine
windmill:
  db_password: "generate-secure-password-here"

# Postfix SMTP relay
postfix:
  smtp_password: "mox-account-password-here"

# Mox email server
mox:
  admin_password: "secure-mox-admin-password"

# Monitoring alerts
monitoring:
  alert_email: "admin@dimosaic.com"

# ============================================
# APPLICATION SECRETS
# ============================================
apps:
  # Personal API
  personal_api:
    db_password: "generate-secure-password-here"
    jwt_secret: "generate-jwt-secret-here"

  # New Product
  newproduct:
    db_password: "generate-secure-password-here"
    jwt_secret: "generate-jwt-secret-here"
    stripe_api_key: "sk_live_xxx"
    stripe_webhook_secret: "whsec_xxx"

# ============================================
# GITHUB CONTAINER REGISTRY (for private images)
# ============================================
registry:
  ghcr:
    username: "github-username"
    token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# ============================================
# DNS PROVIDER SECRETS (Netcup)
# ============================================
dns:
  customer_number: "12345"        # Netcup customer ID (from CCP header)
  api_key: "abc123..."            # Generated in CCP → Stammdaten → API
  api_password: "xyz789..."       # Shown once when generating API key
```

### Secret Generation

Generate secure passwords using:

```bash
# Generate 32-character encryption keys
tr -dc 'A-Za-z0-9!@#$%' </dev/urandom | head -c 32

# Or using openssl
openssl rand -base64 32 | tr -d '/+=' | head -c 32

# For age key generation
age-keygen -o key.txt
```

### Encrypting Secrets

```bash
# Install sops and age
brew install sops age  # macOS
# or
apt install sops age   # Ubuntu

# Generate age key (one-time)
age-keygen -o ~/.config/sops/age/keys.txt

# Get public key for .sops.yaml
age-keygen -y ~/.config/sops/age/keys.txt

# Encrypt secrets file
sops -e config/secrets.yaml > config/secrets.enc.yaml

# Edit encrypted file
sops config/secrets.enc.yaml

# View decrypted content
sops -d config/secrets.enc.yaml
```

## JSON Schema for Validation

### services.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://fidudoc.eu/schemas/services.json",
  "title": "VPS Services Configuration",
  "type": "object",
  "required": ["version", "global", "services"],
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+$"
    },
    "dns": {
      "$ref": "#/$defs/dnsConfig"
    },
    "global": {
      "type": "object",
      "required": ["domain", "timezone"],
      "properties": {
        "domain": { "type": "string", "format": "hostname" },
        "timezone": { "type": "string" },
        "docker": {
          "type": "object",
          "properties": {
            "compose_version": { "type": "string" },
            "network_subnet": { "type": "string" }
          }
        }
      }
    },
    "categories": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["description", "start_order"],
        "properties": {
          "description": { "type": "string" },
          "start_order": { "type": "integer", "minimum": 0 }
        }
      }
    },
    "services": {
      "type": "object",
      "additionalProperties": {
        "$ref": "#/$defs/service"
      }
    },
    "networks": {
      "type": "object",
      "additionalProperties": {
        "$ref": "#/$defs/network"
      }
    }
  },
  "$defs": {
    "service": {
      "type": "object",
      "required": ["enabled", "category", "type"],
      "properties": {
        "enabled": { "type": "boolean" },
        "category": { "enum": ["core", "apps", "host"] },
        "type": { "enum": ["docker", "host"] },
        "image": { "type": "string" },
        "domain": { "type": "string" },
        "depends_on": {
          "type": "array",
          "items": { "type": "string" }
        },
        "environment": {
          "type": "object",
          "additionalProperties": { "type": "string" }
        },
        "volumes": {
          "type": "array",
          "items": { "$ref": "#/$defs/volume" }
        },
        "ports": {
          "type": "array",
          "items": { "$ref": "#/$defs/port" }
        },
        "networks": {
          "type": "array",
          "items": { "type": "string" }
        },
        "resources": { "$ref": "#/$defs/resources" },
        "healthcheck": { "$ref": "#/$defs/healthcheck" },
        "replicas": { "type": "integer", "minimum": 1 }
      }
    },
    "volume": {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "type": { "enum": ["volume", "bind"] },
        "source": { "type": "string" },
        "path": { "type": "string" },
        "target": { "type": "string" },
        "readonly": { "type": "boolean" }
      }
    },
    "port": {
      "type": "object",
      "required": ["container"],
      "properties": {
        "host": { "type": "integer" },
        "container": { "type": "integer" },
        "protocol": { "enum": ["tcp", "udp"] },
        "expose_external": { "type": "boolean" },
        "internal": { "type": "boolean" }
      }
    },
    "resources": {
      "type": "object",
      "properties": {
        "memory": { "type": "string", "pattern": "^\\d+[kmg]?$" },
        "cpus": { "type": "string", "pattern": "^\\d+(\\.\\d+)?$" }
      }
    },
    "healthcheck": {
      "type": "object",
      "required": ["type"],
      "properties": {
        "type": { "enum": ["http", "tcp", "command", "systemd", "logs"] },
        "path": { "type": "string" },
        "port": { "type": "integer" },
        "command": {
          "type": "array",
          "items": { "type": "string" }
        },
        "interval": { "type": "string" },
        "timeout": { "type": "string" },
        "retries": { "type": "integer" }
      }
    },
    "network": {
      "type": "object",
      "properties": {
        "driver": { "enum": ["bridge", "host", "none"] },
        "internal": { "type": "boolean" }
      }
    },
    "dnsConfig": {
      "type": "object",
      "required": ["provider"],
      "properties": {
        "provider": { "enum": ["netcup"] },
        "customer_number_secret": { "type": "string" },
        "api_key_secret": { "type": "string" },
        "api_password_secret": { "type": "string" },
        "zones": {
          "type": "object",
          "additionalProperties": { "$ref": "#/$defs/dnsZone" }
        },
        "propagation_timeout": { "type": "integer", "minimum": 60, "default": 900 },
        "verify_before_deploy": { "type": "boolean", "default": true }
      }
    },
    "dnsZone": {
      "type": "object",
      "required": ["type"],
      "properties": {
        "type": { "enum": ["primary", "external"] },
        "registrar": { "type": "string" },
        "auto_records": { "type": "boolean", "default": true },
        "ttl": { "type": "integer", "minimum": 60, "default": 3600 }
      }
    }
  }
}
```

## Template Variables

The configuration supports template variables using `{{ }}` syntax:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ global.primary_domain }}` | Primary domain | `dimosaic.com` |
| `{{ global.timezone }}` | Server timezone | `Europe/Brussels` |
| `{{ global.admin_email }}` | Admin email | `admin@dimosaic.com` |
| `{{ profile.name }}` | Profile name | `dimosaic` |
| `{{ secrets.X.Y }}` | Infrastructure secret | `{{ secrets.postgres.root_password }}` |
| `{{ secrets.apps.X.Y }}` | App secret | `{{ secrets.apps.personal_api.db_password }}` |

Variables are resolved during configuration loading before deployment.

## Enabling/Disabling Services

To disable a service, set `enabled: false`:

```yaml
services:
  windmill-server:
    enabled: false  # Will not be included in docker-compose.yml
    # ... rest of config preserved for later re-enabling
```

When a service is disabled:
1. It's removed from generated docker-compose.yml
2. Its Caddyfile entries are removed
3. Its database is NOT deleted (data preserved)
4. It can be re-enabled by setting `enabled: true`

## PgBouncer Configuration

### Userlist Generation

The CLI generates `pgbouncer/userlist.txt` from secrets:

```txt
# pgbouncer/userlist.txt (auto-generated)
"postgres" "md5<hash>"
"zitadel" "md5<hash>"
"windmill_user" "md5<hash>"
"windmill_admin" "md5<hash>"
"personal_api" "md5<hash>"
"newproduct" "md5<hash>"
```

### Connection Strings

Services connect through PgBouncer on port 6432:

```yaml
# Infrastructure services (can use direct or pooled)
DATABASE_URL: "postgresql://zitadel:password@pgbouncer:6432/zitadel"

# Custom apps (always use pooled)
DATABASE_URL: "postgresql://personal_api:password@pgbouncer:6432/personal_api"
```

### Pool Modes

| Mode | Use Case | Session State |
|------|----------|---------------|
| `transaction` | Most apps (default) | Reset per transaction |
| `session` | Apps with prepared statements | Persistent |
| `statement` | Simple queries only | Reset per statement |

## Application Deployment

### Static Frontend Apps

Static apps are built via CI/CD and deployed to `/var/www/<app-name>/`:

```yaml
# In profile
domains:
  dimosaic.com:
    apps:
      - name: personal-site
        subdomain: ""
        type: static
        path: /var/www/dimosaic
        # Optional SPA routing
        spa: true
```

Generated Caddyfile:
```caddyfile
dimosaic.com {
    root * /var/www/dimosaic
    file_server
    try_files {path} /index.html  # SPA routing
}
```

### Container Backend Apps

Container apps are pulled from registry and managed via Docker Compose:

```yaml
# In profile
domains:
  dimosaic.com:
    apps:
      - name: personal-api
        subdomain: api
        type: container
        image: ghcr.io/dimosaic/personal-api:latest
        port: 3000
        environment:
          NODE_ENV: production
          DATABASE_URL: "postgresql://personal_api:{{ secrets.apps.personal_api.db_password }}@pgbouncer:6432/personal_api"
          REDIS_URL: "redis://redis:6379"
        healthcheck:
          type: http
          path: /health
          port: 3000
        resources:
          memory: 512m
          cpus: "0.5"
```

Generated docker-compose.yml addition:
```yaml
services:
  personal-api:
    image: ghcr.io/dimosaic/personal-api:latest
    container_name: personal-api
    restart: unless-stopped
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://personal_api:xxx@pgbouncer:6432/personal_api
      REDIS_URL: redis://redis:6379
    networks:
      - web
    mem_limit: 512m
    cpus: 0.5
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### GitHub Container Registry Authentication

For private images, configure registry credentials:

```yaml
# In secrets
registry:
  ghcr:
    username: "github-username"
    token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

The CLI runs `docker login` before pulling:
```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
```

## Profile Merging

When deploying, profile config is merged with base config:

1. Load `config/base.yaml` (infrastructure services)
2. Load `config/profiles/<name>.yaml` (domains, apps, overrides)
3. Load `config/secrets/<name>.enc.yaml` (decrypt and merge)
4. Apply resource overrides from profile
5. Generate final docker-compose.yml and Caddyfile

```bash
# Deploy with specific profile
vps deploy --host 1.2.3.4 --profile dimosaic

# Profile can also be set via environment
VPS_PROFILE=dimosaic vps deploy --host 1.2.3.4
```
