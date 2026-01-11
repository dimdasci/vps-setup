# System Architecture

## Project Structure

```
fdd-vps-automation/
├── package.json
├── bunfig.toml
├── tsconfig.json
├── .sops.yaml                      # SOPS configuration for age encryption
├── .gitignore
├── README.md
│
├── config/
│   ├── base.yaml                   # Infrastructure service definitions
│   ├── profiles/
│   │   ├── dimosaic.yaml          # Personal VPS profile
│   │   └── easybiz.yaml           # Business VPS profile
│   ├── secrets/
│   │   ├── dimosaic.enc.yaml      # Encrypted secrets for dimosaic
│   │   └── easybiz.enc.yaml       # Encrypted secrets for easybiz
│   └── schemas/
│       ├── base.schema.json        # JSON Schema for base config
│       ├── profile.schema.json     # JSON Schema for profile config
│       └── secrets.schema.json     # JSON Schema for secrets validation
│
├── src/
│   ├── index.ts                    # CLI entry point
│   ├── cli/
│   │   ├── commands/
│   │   │   ├── provision.ts        # Initial server setup command
│   │   │   ├── deploy.ts           # Deploy/update services command
│   │   │   ├── validate.ts         # Health check command
│   │   │   ├── secrets.ts          # Secret management commands
│   │   │   ├── cert-sync.ts        # Certificate sync command
│   │   │   ├── status.ts           # Status display command
│   │   │   ├── rollback.ts         # Rollback to previous state
│   │   │   └── dns.ts              # DNS management commands
│   │   └── index.ts                # CLI setup with Commander
│   │
│   ├── core/
│   │   ├── config/
│   │   │   ├── loader.ts           # YAML config loading
│   │   │   ├── validator.ts        # Config validation
│   │   │   └── types.ts            # TypeScript types for config
│   │   ├── secrets/
│   │   │   ├── sops.ts             # SOPS decryption wrapper
│   │   │   └── age.ts              # age key management
│   │   ├── ssh/
│   │   │   ├── client.ts           # SSH connection wrapper
│   │   │   ├── executor.ts         # Remote command execution
│   │   │   └── sftp.ts             # File transfer utilities
│   │   └── state/
│   │       ├── tracker.ts          # Deployment state tracking
│   │       └── diff.ts             # State diffing for idempotency
│   │
│   ├── provisioners/
│   │   ├── base.ts                 # Base provisioner interface
│   │   ├── system/
│   │   │   ├── packages.ts         # APT package installation
│   │   │   ├── users.ts            # User creation (app, mox)
│   │   │   ├── firewall.ts         # UFW configuration
│   │   │   └── docker.ts           # Docker installation
│   │   ├── docker/
│   │   │   ├── compose.ts          # Docker Compose operations
│   │   │   ├── networks.ts         # Network management
│   │   │   └── volumes.ts          # Volume management
│   │   └── host/
│   │       └── mox.ts              # Mox installation (non-Docker)
│   │
│   ├── services/
│   │   ├── registry.ts             # Service registry and discovery
│   │   ├── base.ts                 # Base service interface
│   │   ├── core/                   # Infrastructure services
│   │   │   ├── caddy.ts
│   │   │   ├── postgres.ts
│   │   │   ├── pgbouncer.ts        # Connection pooler
│   │   │   └── redis.ts
│   │   ├── apps/                   # Platform services
│   │   │   ├── zitadel.ts
│   │   │   ├── windmill.ts
│   │   │   └── postfix.ts
│   │   ├── custom/                 # Custom app services (dynamic)
│   │   │   ├── static-app.ts       # Static frontend handler
│   │   │   └── container-app.ts    # Container backend handler
│   │   └── host/                   # Host-level services
│   │       └── mox.ts
│   │
│   ├── generators/
│   │   ├── docker-compose.ts       # Generate docker-compose.yml
│   │   ├── caddyfile.ts            # Generate Caddyfile
│   │   ├── init-db.ts              # Generate init-db.sh
│   │   ├── pgbouncer.ts            # Generate pgbouncer userlist.txt
│   │   ├── env.ts                  # Generate .env file
│   │   └── mox-config.ts           # Generate Mox configuration
│   │
│   ├── validators/
│   │   ├── index.ts                # Validation orchestrator
│   │   ├── health/
│   │   │   ├── http.ts             # HTTP endpoint checks
│   │   │   ├── tcp.ts              # TCP port checks
│   │   │   ├── docker.ts           # Docker container health
│   │   │   └── database.ts         # Database connectivity
│   │   ├── logs/
│   │   │   ├── parser.ts           # Log parsing utilities
│   │   │   └── analyzer.ts         # Error pattern detection
│   │   └── certificates/
│   │       └── checker.ts          # SSL certificate validation
│   │
│   ├── sync/
│   │   └── certificates/
│   │       ├── caddy.ts            # Extract certs from Caddy
│   │       ├── mox.ts              # Deploy certs to Mox
│   │       └── watcher.ts          # Certificate renewal monitoring
│   │
│   ├── dns/
│   │   ├── index.ts                # DNS module exports
│   │   ├── types.ts                # DNS-related types
│   │   ├── records.ts              # DNS record generation (email, apps)
│   │   ├── validator.ts            # Propagation validation using dig
│   │   ├── diff.ts                 # Record diffing logic
│   │   └── providers/
│   │       ├── base.ts             # DNS provider interface
│   │       └── netcup.ts           # Netcup DNS API client
│   │
│   ├── monitor/
│   │   ├── daemon.ts               # Monitoring daemon
│   │   ├── checks.ts               # Health check definitions
│   │   └── alerts/
│   │       ├── email.ts            # Email alerting via Mox
│   │       └── webhook.ts          # Webhook alerting (optional)
│   │
│   └── utils/
│       ├── logger.ts               # Structured logging
│       ├── retry.ts                # Retry with backoff
│       ├── template.ts             # Template rendering
│       └── idempotent.ts           # Idempotency helpers
│
├── templates/
│   ├── docker-compose/
│   │   ├── base.yaml.hbs           # Base compose structure
│   │   └── service.yaml.hbs        # Service block template
│   ├── caddy/
│   │   ├── base.hbs                # Base Caddyfile structure
│   │   └── site.hbs                # Site block template
│   ├── systemd/
│   │   └── mox.service.hbs         # Mox systemd service
│   └── scripts/
│       └── init-db.sh.hbs          # Database init script
│
└── tests/
    ├── unit/
    │   ├── generators/
    │   ├── validators/
    │   └── services/
    ├── integration/
    │   └── docker/
    └── fixtures/
        ├── services.test.yaml
        ├── secrets.test.yaml
        └── expected/
```

## Core TypeScript Types

```typescript
// src/core/config/types.ts

// ============================================
// BASE CONFIGURATION (infrastructure services)
// ============================================

export interface BaseConfig {
  version: string;
  global: GlobalDefaults;
  categories: Record<string, CategoryConfig>;
  services: Record<string, ServiceDefinition>;
  networks: Record<string, NetworkConfig>;
}

export interface GlobalDefaults {
  timezone: string;
  docker: DockerGlobalConfig;
}

export interface DockerGlobalConfig {
  compose_version: string;
  network_subnet: string;
}

export interface CategoryConfig {
  description: string;
  start_order: number;
}

// ============================================
// PROFILE CONFIGURATION (per-VPS settings)
// ============================================

export interface ProfileConfig {
  version: string;
  profile: ProfileMetadata;
  global: ProfileGlobalConfig;
  domains: Record<string, DomainConfig>;
  resources?: ResourceOverrides;
  databases?: DatabaseConfig[];
  dns?: DnsConfig;
}

export interface ProfileMetadata {
  name: string;
  description: string;
}

export interface ProfileGlobalConfig {
  primary_domain: string;
  timezone: string;
  admin_email: string;
  docker?: DockerGlobalConfig;
}

export interface DomainConfig {
  description?: string;
  apps: AppDefinition[];
}

export interface AppDefinition {
  name: string;
  subdomain: string;              // "" for root domain
  type: 'static' | 'container';

  // Static app
  path?: string;
  spa?: boolean;

  // Container app
  image?: string;
  port?: number;
  environment?: Record<string, string>;
  healthcheck?: HealthCheckConfig;
  resources?: ResourceLimits;
  depends_on?: string[];
}

export interface ResourceOverrides {
  [serviceName: string]: Partial<ResourceLimits> & { replicas?: number };
}

// ============================================
// MERGED CONFIGURATION (runtime)
// ============================================

export interface MergedConfig {
  version: string;
  profile: ProfileMetadata;
  global: MergedGlobalConfig;
  categories: Record<string, CategoryConfig>;
  services: Record<string, ServiceDefinition>;
  domains: Record<string, DomainConfig>;
  networks: Record<string, NetworkConfig>;
  databases: DatabaseConfig[];
}

export interface MergedGlobalConfig {
  primary_domain: string;
  timezone: string;
  admin_email: string;
  docker: DockerGlobalConfig;
}

export interface ServiceDefinition {
  enabled: boolean;
  category: 'core' | 'apps' | 'host';
  type: 'docker' | 'host';

  // Docker-specific
  image?: string;
  build?: BuildConfig;
  domain?: string;
  additional_domains?: string[];
  depends_on?: string[];
  environment?: Record<string, string>;
  volumes?: VolumeMount[];
  ports?: PortMapping[];
  networks?: string[];
  resources?: ResourceLimits;
  replicas?: number;
  user?: string;
  command?: string | string[];

  // Caddy configuration
  caddy?: CaddyConfig;

  // Database requirements
  databases?: DatabaseConfig[];

  // Health check
  healthcheck?: HealthCheckConfig;

  // Host service specific
  home?: string;
  systemd?: SystemdConfig;
  certificates?: CertificateConfig;
  internal_ports?: InternalPort[];
}

export interface BuildConfig {
  context: string;
  dockerfile: string;
  args?: Record<string, string>;
}

export interface VolumeMount {
  name?: string;
  type?: 'volume' | 'bind';
  source?: string;
  path: string;
  target?: string;
  readonly?: boolean;
}

export interface PortMapping {
  host?: number;
  container: number;
  protocol?: 'tcp' | 'udp';
  expose_external?: boolean;
  internal?: boolean;
  description?: string;
}

export interface ResourceLimits {
  memory: string;
  cpus: string;
}

export interface CaddyConfig {
  security_headers?: boolean;
  frame_options?: 'DENY' | 'SAMEORIGIN';
  protocol?: 'http' | 'h2c';
  proxy_headers?: string[];
  routes?: CaddyRoute[];
}

export interface CaddyRoute {
  path: string;
  upstream: string;
}

export interface DatabaseConfig {
  name: string;
  user: string;
  password_secret: string;
  extra_users?: ExtraDbUser[];
}

export interface ExtraDbUser {
  name: string;
  password_secret: string;
  options?: string;
}

export interface HealthCheckConfig {
  type: 'http' | 'tcp' | 'command' | 'systemd';
  path?: string;
  port?: number;
  command?: string[];
  service?: string;
  interval?: string;
  timeout?: string;
  retries?: number;
  start_period?: string;
  internal?: boolean;
}

export interface SystemdConfig {
  service_name: string;
  type?: 'simple' | 'notify' | 'forking';
}

export interface CertificateConfig {
  source: 'caddy' | 'acme' | 'manual';
  domains: string[];
  target_path: string;
}

export interface InternalPort {
  port: number;
  listen: string;
  description: string;
}

// ============================================
// DNS CONFIGURATION (Netcup)
// ============================================

export interface DnsConfig {
  provider: 'netcup';
  customer_number_secret: string;
  api_key_secret: string;
  api_password_secret: string;
  zones: Record<string, DnsZoneConfig>;
  propagation_timeout: number;  // seconds
  verify_before_deploy: boolean;
}

export interface DnsZoneConfig {
  type: 'primary' | 'external';
  registrar?: string;          // informational for external domains
  auto_records: boolean;
  ttl: number;
}

export interface DnsRecord {
  hostname: string;            // subdomain or @ for root
  type: 'A' | 'AAAA' | 'CNAME' | 'MX' | 'TXT' | 'SRV';
  value: string;
  priority?: number;           // for MX records
}

export interface DnsZoneState {
  zone: string;
  records: DnsRecord[];
  lastSync: string;            // ISO timestamp
}

export interface NetworkConfig {
  driver: 'bridge' | 'host' | 'none';
  internal?: boolean;
}

// ============================================
// SECRETS
// ============================================

export interface SecretsConfig {
  // Infrastructure secrets
  postgres: {
    root_password: string;
  };
  zitadel: {
    db_password: string;
    masterkey: string;
    org_name: string;
    admin_email: string;
    admin_password: string;
  };
  windmill: {
    db_password: string;
  };
  postfix: {
    smtp_password: string;
  };
  mox: {
    admin_password: string;
  };
  monitoring: {
    alert_email: string;
  };

  // Application secrets (dynamic per app)
  apps: Record<string, AppSecrets>;

  // Registry credentials
  registry?: RegistryConfig;
}

export interface AppSecrets {
  db_password?: string;
  jwt_secret?: string;
  [key: string]: string | undefined;  // Allow custom secrets per app
}

export interface RegistryConfig {
  ghcr?: {
    username: string;
    token: string;
  };
  dockerhub?: {
    username: string;
    token: string;
  };
}

// ============================================
// DEPLOYMENT STATE
// ============================================

export interface DeploymentState {
  version: string;
  timestamp: string;
  host: string;
  services: Record<string, ServiceState>;
  configHash: string;
  secretsHash: string;
}

export interface ServiceState {
  enabled: boolean;
  image?: string;
  imageDigest?: string;
  configHash: string;
  status: 'running' | 'stopped' | 'failed' | 'unknown';
  lastDeployed: string;
}

// ============================================
// VALIDATION
// ============================================

export interface ValidationResult {
  status: 'pass' | 'warn' | 'fail';
  checks: CheckResult[];
  summary: ValidationSummary;
  timestamp: string;
}

export interface CheckResult {
  name: string;
  category: 'infrastructure' | 'container' | 'endpoint' | 'certificate' | 'logs';
  service?: string;
  status: 'pass' | 'warn' | 'fail';
  message: string;
  details?: Record<string, unknown>;
  duration: number;
}

export interface ValidationSummary {
  total: number;
  passed: number;
  warnings: number;
  failed: number;
}

// ============================================
// PROVISIONER INTERFACES
// ============================================

export interface Provisioner {
  name: string;
  check(): Promise<ProvisionerStatus>;
  provision(): Promise<ProvisionResult>;
  rollback?(): Promise<void>;
}

export interface ProvisionerStatus {
  needsProvisioning: boolean;
  currentState: Record<string, unknown>;
  targetState: Record<string, unknown>;
}

export interface ProvisionResult {
  success: boolean;
  message: string;
  details?: Record<string, unknown>;
}

// ============================================
// SSH
// ============================================

export interface SSHConfig {
  host: string;
  port?: number;
  username: string;
  privateKeyPath?: string;
  password?: string;
}

export interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
  duration: number;
}
```

## Service Registry Pattern

Each service implements a common interface for configuration generation:

```typescript
// src/services/base.ts

export interface Service {
  name: string;
  category: 'core' | 'apps' | 'host';
  type: 'docker' | 'host';

  // Return Docker Compose service definition
  getComposeConfig(config: ServiceDefinition, secrets: SecretsConfig): ComposeService;

  // Return Caddyfile blocks for this service
  getCaddyConfig(config: ServiceDefinition): string;

  // Return database initialization SQL
  getDatabaseInit?(config: ServiceDefinition, secrets: SecretsConfig): string;

  // Return health check configuration
  getHealthChecks(config: ServiceDefinition): HealthCheckConfig[];

  // Service-specific validation
  validate?(config: ServiceDefinition): ValidationError[];
}

// src/services/registry.ts

export class ServiceRegistry {
  private services: Map<string, Service> = new Map();

  register(service: Service): void {
    this.services.set(service.name, service);
  }

  get(name: string): Service | undefined {
    return this.services.get(name);
  }

  getEnabled(config: ServiceConfig): Service[] {
    return Array.from(this.services.values())
      .filter(s => config.services[s.name]?.enabled);
  }

  getByCategory(category: string): Service[] {
    return Array.from(this.services.values())
      .filter(s => s.category === category);
  }
}
```

## Generator Pipeline

Configuration generation follows a pipeline with profile merging:

```
┌─────────────┐     ┌─────────────┐     ┌────────────────┐
│  base.yaml  │────▶│   Config    │────▶│   Service      │
│             │     │   Merger    │     │   Registry     │
└─────────────┘     └─────────────┘     └────────────────┘
                           ▲                    │
┌─────────────┐            │                    ▼
│  profile/   │────────────┤            ┌────────────────┐
│  <name>.yaml│            │            │   Generators   │
└─────────────┘            │            └────────────────┘
                           │                    │
┌─────────────┐            │                    ▼
│  secrets/   │────────────┘            ┌────────────────┐
│  <name>.enc │                         │  Generated     │
└─────────────┘                         │  Files:        │
                                        │  - compose.yml │
                                        │  - Caddyfile   │
                                        │  - init-db.sh  │
                                        │  - pgbouncer/  │
                                        │  - .env        │
                                        └────────────────┘
```

### Profile Merging Process

```typescript
// src/core/config/merger.ts

export function mergeConfig(
  base: BaseConfig,
  profile: ProfileConfig,
  secrets: SecretsConfig
): MergedConfig {
  return {
    version: profile.version,
    profile: profile.profile,
    global: {
      primary_domain: profile.global.primary_domain,
      timezone: profile.global.timezone || base.global.timezone,
      admin_email: profile.global.admin_email,
      docker: profile.global.docker || base.global.docker,
    },
    categories: base.categories,
    services: applyResourceOverrides(base.services, profile.resources),
    domains: profile.domains,
    networks: base.networks,
    databases: [
      ...getInfrastructureDatabases(base.services),
      ...(profile.databases || []),
    ],
  };
}
```

## Idempotency Strategy

All operations check current state before acting:

```typescript
// src/utils/idempotent.ts

export async function idempotent<T>(
  name: string,
  check: () => Promise<boolean>,
  action: () => Promise<T>,
  options?: { force?: boolean }
): Promise<{ skipped: boolean; result?: T }> {

  if (!options?.force) {
    const alreadyDone = await check();
    if (alreadyDone) {
      logger.info(`${name}: Already done, skipping`);
      return { skipped: true };
    }
  }

  logger.info(`${name}: Executing...`);
  const result = await action();
  return { skipped: false, result };
}
```

## State Tracking

Deployment state is stored on the server for rollback capability:

```
/home/app/docker/
├── .vps-state/
│   ├── current.json           # Current deployment state
│   ├── history/
│   │   ├── 2025-01-09T10-30-00.json
│   │   └── 2025-01-08T15-45-00.json
│   └── backups/
│       └── 2025-01-09T10-30-00/
│           ├── docker-compose.yml
│           ├── Caddyfile
│           └── .env
```

## Error Handling

All operations use structured error types:

```typescript
// src/core/errors.ts

export class VPSError extends Error {
  constructor(
    message: string,
    public code: string,
    public recoverable: boolean = true,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'VPSError';
  }
}

export class SSHError extends VPSError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'SSH_ERROR', true, details);
  }
}

export class ConfigError extends VPSError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'CONFIG_ERROR', false, details);
  }
}

export class ProvisionError extends VPSError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'PROVISION_ERROR', true, details);
  }
}
```
