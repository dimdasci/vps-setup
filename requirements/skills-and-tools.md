# Skills and Tools

## Overview

This document outlines the technical skills required to implement the VPS automation system and recommends specific tools and libraries for each component.

## Required Skills

### Core Skills (Essential)

| Skill | Level | Used For |
|-------|-------|----------|
| **TypeScript** | Advanced | All automation code, type safety |
| **Node.js/Bun Runtime** | Intermediate | Runtime environment, async patterns |
| **Linux Administration** | Intermediate | SSH, systemd, file permissions |
| **Docker & Docker Compose** | Intermediate | Container orchestration |
| **Bash Scripting** | Basic | Shell commands, system scripts |
| **YAML** | Basic | Configuration files |

### Infrastructure Skills (Important)

| Skill | Level | Used For |
|-------|-------|----------|
| **SSH/SFTP** | Intermediate | Remote server management |
| **Networking** | Basic | Ports, DNS, firewalls |
| **DNS API** | Basic | Netcup DNS record management |
| **TLS/SSL** | Basic | Certificate management |
| **PostgreSQL** | Basic | Database initialization |
| **Email (SMTP/IMAP)** | Basic | Mox configuration |

### DevOps Skills (Helpful)

| Skill | Level | Used For |
|-------|-------|----------|
| **Git** | Intermediate | Version control, secrets management |
| **CI/CD** | Basic | Automated testing |
| **Monitoring** | Basic | Health checks, alerting |
| **Testing** | Intermediate | Unit, integration, E2E tests |

## Recommended Tools and Libraries

### Runtime

| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| **Bun** | 1.x | JavaScript/TypeScript runtime | Fast, built-in TS support, test runner |

```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Verify
bun --version
```

### CLI Framework

| Library | Purpose | Alternative |
|---------|---------|-------------|
| **Commander.js** | CLI argument parsing | Yargs, Cliffy |
| **Inquirer.js** | Interactive prompts | Prompts |
| **Chalk** | Terminal styling | Picocolors |
| **Ora** | Spinners/progress | cli-spinners |

```typescript
// package.json dependencies
{
  "dependencies": {
    "commander": "^12.0.0",
    "inquirer": "^9.0.0",
    "chalk": "^5.3.0",
    "ora": "^8.0.0"
  }
}
```

### SSH and Remote Execution

| Library | Purpose | Alternative |
|---------|---------|-------------|
| **ssh2** | Low-level SSH client | - |
| **node-ssh** | High-level SSH wrapper | ssh2-promise |
| **ssh2-sftp-client** | File transfers | node-ssh (built-in) |

```typescript
// Example usage
import { NodeSSH } from 'node-ssh';

const ssh = new NodeSSH();
await ssh.connect({
  host: '203.0.113.50',
  username: 'app',
  privateKeyPath: '~/.ssh/id_rsa',
});

const result = await ssh.execCommand('docker ps');
console.log(result.stdout);
```

### Configuration and Validation

| Library | Purpose | Alternative |
|---------|---------|-------------|
| **yaml** | YAML parsing | js-yaml |
| **Ajv** | JSON Schema validation | Zod, Yup |
| **dotenv** | Environment variables | - |

```typescript
// Example: Config validation with Ajv
import Ajv from 'ajv';
import schema from './schemas/services.schema.json';

const ajv = new Ajv();
const validate = ajv.compile(schema);

if (!validate(config)) {
  console.error(validate.errors);
}
```

### Secrets Management

| Tool | Purpose | Notes |
|------|---------|-------|
| **SOPS** | Secret encryption | Mozilla's tool, supports age |
| **age** | Encryption | Modern, simple key management |

```bash
# Install
brew install sops age  # macOS
apt install sops age   # Ubuntu

# Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# Encrypt file
sops -e secrets.yaml > secrets.enc.yaml

# Decrypt in code
sops -d secrets.enc.yaml
```

```typescript
// TypeScript wrapper for SOPS
import { exec } from 'child_process';
import { promisify } from 'util';
const execAsync = promisify(exec);

export async function decryptSecrets(path: string): Promise<object> {
  const { stdout } = await execAsync(`sops -d ${path}`);
  return YAML.parse(stdout);
}
```

### Template Rendering

| Library | Purpose | Alternative |
|---------|---------|-------------|
| **Handlebars** | Template engine | EJS, Mustache, Nunjucks |

```typescript
import Handlebars from 'handlebars';

const template = Handlebars.compile(`
server {
  listen {{ port }};
  server_name {{ domain }};
}
`);

const output = template({ port: 80, domain: 'example.com' });
```

### Testing

| Library | Purpose | Notes |
|---------|---------|-------|
| **Bun test** | Unit/integration tests | Built into Bun runtime |
| **Testcontainers** | Docker-based tests | For integration tests |

```typescript
// Bun test example
import { describe, test, expect, beforeAll } from 'bun:test';

describe('ConfigLoader', () => {
  test('loads valid YAML', () => {
    const config = loadConfig('./fixtures/test.yaml');
    expect(config.version).toBe('1.0');
  });
});
```

### Logging

| Library | Purpose | Alternative |
|---------|---------|-------------|
| **Pino** | Structured logging | Winston, Bunyan |

```typescript
import pino from 'pino';

const logger = pino({
  level: 'info',
  transport: {
    target: 'pino-pretty',
    options: { colorize: true },
  },
});

logger.info({ service: 'deploy' }, 'Deployment started');
```

### HTTP Client

| Library | Purpose | Notes |
|---------|---------|-------|
| **fetch** | HTTP requests | Built into Bun/Node |
| **got** | Advanced HTTP | If fetch is insufficient |

```typescript
// Built-in fetch
const response = await fetch('https://example.com/health');
if (!response.ok) {
  throw new Error(`HTTP ${response.status}`);
}
```

### Email (for alerts)

| Library | Purpose | Notes |
|---------|---------|-------|
| **Nodemailer** | SMTP client | Standard Node.js email library |

```typescript
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: 'localhost',
  port: 587,
  secure: false,
});

await transporter.sendMail({
  from: 'monitor@fidudoc.eu',
  to: 'admin@fidudoc.eu',
  subject: 'Alert',
  text: 'Service down',
});
```

### DNS Automation (Netcup)

| Tool | Purpose | Notes |
|------|---------|-------|
| **Native fetch** | API calls | JSON-RPC to Netcup endpoint |
| **dig** | DNS verification | Check propagation via shell |

The Netcup DNS API uses JSON-RPC:

```typescript
// Netcup DNS API client
const NETCUP_API = 'https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON';

interface NetcupApiParams {
  customernumber: string;
  apikey: string;
  apipassword?: string;
  apisessionid?: string;
  domainname?: string;
  dnsrecordset?: { dnsrecords: DnsRecord[] };
}

async function netcupApi<T>(action: string, params: NetcupApiParams): Promise<T> {
  const response = await fetch(NETCUP_API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, param: params }),
  });

  const result = await response.json();
  if (result.status !== 'success') {
    throw new Error(`Netcup API error: ${result.longmessage}`);
  }
  return result.responsedata;
}

// Usage
const session = await netcupApi<{ apisessionid: string }>('login', {
  customernumber: '12345',
  apikey: 'abc...',
  apipassword: 'xyz...',
});

const records = await netcupApi<{ dnsrecords: DnsRecord[] }>('infoDnsRecords', {
  customernumber: '12345',
  apikey: 'abc...',
  apisessionid: session.apisessionid,
  domainname: 'example.com',
});
```

**Propagation validation:**

```typescript
import { exec } from 'child_process';
import { promisify } from 'util';
const execAsync = promisify(exec);

async function checkDnsPropagation(
  hostname: string,
  type: string,
  expected: string
): Promise<boolean> {
  const { stdout } = await execAsync(`dig @8.8.8.8 ${type} ${hostname} +short`);
  return stdout.trim().includes(expected);
}
```

## Development Tools

### IDE and Editor

| Tool | Purpose | Extensions |
|------|---------|------------|
| **VS Code** | Primary editor | ESLint, Prettier, Docker |
| **Cursor** | AI-assisted | Same as VS Code |

Recommended VS Code extensions:
- ESLint
- Prettier
- Docker
- YAML
- Remote - SSH (for debugging on VPS)

### Local Development

| Tool | Purpose | Notes |
|------|---------|-------|
| **Docker Desktop** | Local containers | For integration tests |
| **Vagrant** | Local VMs | For E2E tests |
| **VirtualBox** | VM provider | Required for Vagrant |

```bash
# Vagrant for E2E testing
vagrant init ubuntu/jammy64
vagrant up
vagrant ssh
```

### Debugging

| Tool | Purpose |
|------|---------|
| **Bun debugger** | TypeScript debugging |
| **VS Code debugger** | Breakpoints, stepping |
| **console.log** | Quick debugging |

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "bun",
      "request": "launch",
      "name": "Debug CLI",
      "program": "${workspaceFolder}/src/index.ts",
      "args": ["provision", "--dry-run"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

## Recommended Package.json

```json
{
  "name": "fdd-vps-automation",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "bun run src/index.ts",
    "build": "bun build src/index.ts --outdir dist --target bun",
    "test": "bun test",
    "test:unit": "bun test tests/unit",
    "test:integration": "bun test tests/integration",
    "lint": "eslint src tests",
    "format": "prettier --write src tests"
  },
  "dependencies": {
    "commander": "^12.0.0",
    "inquirer": "^9.2.0",
    "chalk": "^5.3.0",
    "ora": "^8.0.0",
    "node-ssh": "^13.2.0",
    "ssh2-sftp-client": "^10.0.0",
    "yaml": "^2.3.0",
    "ajv": "^8.12.0",
    "handlebars": "^4.7.8",
    "pino": "^8.17.0",
    "pino-pretty": "^10.3.0",
    "nodemailer": "^6.9.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "@types/node": "^20.0.0",
    "@types/ssh2": "^1.11.0",
    "@types/nodemailer": "^6.4.0",
    "typescript": "^5.3.0",
    "eslint": "^8.56.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "prettier": "^3.2.0"
  }
}
```

## Specialized Skills for Enhancement

These skills are not required but would significantly enhance the implementation:

### 1. Infrastructure as Code (IaC)

**Benefit**: Better abstraction for cloud resources if expanding beyond single VPS.

| Tool | Use Case |
|------|----------|
| Pulumi | TypeScript-native IaC |
| Terraform | Industry standard |

### 2. Container Orchestration

**Benefit**: If scaling beyond single VPS or needing more sophisticated deployments.

| Tool | Use Case |
|------|----------|
| Docker Swarm | Simple multi-node |
| Kubernetes | Enterprise scale |

### 3. Observability

**Benefit**: More sophisticated monitoring if resources allow.

| Tool | Use Case |
|------|----------|
| Prometheus | Metrics collection |
| Grafana | Visualization |
| Loki | Log aggregation |

### 4. Security

**Benefit**: Enhanced security posture.

| Skill | Use Case |
|-------|----------|
| Vault | Enterprise secrets |
| Fail2ban | Intrusion prevention |
| SELinux/AppArmor | Mandatory access control |

## Learning Resources

### TypeScript/Bun

- [Bun Documentation](https://bun.sh/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/)
- [Effect-TS](https://effect.website/) (for advanced error handling)

### Docker/DevOps

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Spec](https://docs.docker.com/compose/compose-file/)
- [Caddy Documentation](https://caddyserver.com/docs/)

### SSH/Linux

- [SSH Mastery](https://www.tiltedwindmillpress.com/product/ssh-mastery-2nd-edition/)
- [Linux Command Line](https://linuxcommand.org/)
- [Systemd Documentation](https://systemd.io/)

### Security

- [OWASP Guidelines](https://owasp.org/)
- [age encryption](https://age-encryption.org/)
- [SOPS Documentation](https://getsops.io/)

## Implementation Team Recommendations

### Minimum Team

For this project, a **single experienced DevOps engineer** with strong TypeScript skills can implement the full system. Key qualifications:

- 3+ years TypeScript/Node.js
- 2+ years Linux/Docker administration
- Experience with SSH automation
- Understanding of TLS/certificates

### Ideal Team (if resources allow)

| Role | Responsibility |
|------|----------------|
| Lead DevOps Engineer | Architecture, core implementation |
| Backend Developer | CLI, testing, documentation |

### External Resources

Consider contracting for:
- Security audit of completed system
- Code review by senior DevOps engineer
- Documentation review for completeness

## Tool Installation Summary

```bash
# macOS
brew install bun sops age vagrant

# Ubuntu/Debian
curl -fsSL https://bun.sh/install | bash
apt install sops age vagrant

# Verify installations
bun --version
sops --version
age --version
vagrant --version
```

## Project Scaffolding

```bash
# Initialize project
mkdir fdd-vps-automation && cd fdd-vps-automation
bun init

# Install dependencies
bun add commander inquirer chalk ora node-ssh yaml ajv handlebars pino nodemailer
bun add -d @types/bun @types/node @types/ssh2 typescript eslint prettier

# Create directory structure
mkdir -p src/{cli/commands,core/{config,secrets,ssh,state},provisioners/{system,docker,host},services/{core,apps,host},generators,validators/{health,logs,certificates},sync/certificates,monitor/alerts,utils}
mkdir -p config/{schemas,hosts}
mkdir -p templates/{docker-compose,caddy,systemd,scripts}
mkdir -p tests/{unit,integration,e2e,fixtures}
```
