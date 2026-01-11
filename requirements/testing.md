# Testing Strategy

## Overview

Testing the VPS automation system requires multiple levels:

1. **Unit Tests** - Test individual components in isolation
2. **Integration Tests** - Test component interactions with real services
3. **End-to-End Tests** - Test full provisioning on virtual machines

## Test Pyramid

```
                    ┌─────────┐
                    │   E2E   │  ~10 tests (slow, expensive)
                    │  Tests  │  Full provisioning on VM
                    └────┬────┘
                         │
                ┌────────┴────────┐
                │  Integration    │  ~50 tests (medium speed)
                │     Tests       │  Docker, SSH, SOPS
                └────────┬────────┘
                         │
        ┌────────────────┴────────────────┐
        │          Unit Tests              │  ~200 tests (fast)
        │  Generators, Validators, Config  │
        └──────────────────────────────────┘
```

## 1. Unit Tests

### What to Test

- Configuration loading and validation
- Template rendering (docker-compose, Caddyfile)
- Secret encryption/decryption mocking
- State diffing algorithms
- Health check logic
- Service registry

### Test Framework

Use Bun's built-in test runner:

```typescript
// tests/unit/generators/docker-compose.test.ts
import { describe, test, expect } from 'bun:test';
import { DockerComposeGenerator } from '../../../src/generators/docker-compose';

describe('DockerComposeGenerator', () => {
  test('generates valid compose for single service', () => {
    const config = {
      services: {
        postgres: {
          enabled: true,
          type: 'docker',
          image: 'postgres:16',
          ports: [{ host: 5432, container: 5432 }],
          volumes: [{ name: 'postgres-data', path: '/var/lib/postgresql/data' }],
          networks: ['web'],
          resources: { memory: '2g', cpus: '1.5' },
        },
      },
      networks: { web: { driver: 'bridge' } },
    };

    const generator = new DockerComposeGenerator();
    const result = generator.generate(config);

    expect(result).toContain('postgres:');
    expect(result).toContain('image: postgres:16');
    expect(result).toContain('5432:5432');
    expect(result).toContain('postgres-data:/var/lib/postgresql/data');
    expect(result).toContain('mem_limit: 2g');
  });

  test('excludes disabled services', () => {
    const config = {
      services: {
        postgres: { enabled: true, type: 'docker', image: 'postgres:16' },
        redis: { enabled: false, type: 'docker', image: 'redis:alpine' },
      },
    };

    const generator = new DockerComposeGenerator();
    const result = generator.generate(config);

    expect(result).toContain('postgres:');
    expect(result).not.toContain('redis:');
  });

  test('handles service dependencies', () => {
    const config = {
      services: {
        postgres: { enabled: true, type: 'docker', image: 'postgres:16' },
        zitadel: {
          enabled: true,
          type: 'docker',
          image: 'ghcr.io/zitadel/zitadel:latest',
          depends_on: ['postgres'],
        },
      },
    };

    const generator = new DockerComposeGenerator();
    const result = generator.generate(config);

    expect(result).toContain('depends_on:');
    expect(result).toContain('postgres:');
    expect(result).toContain('condition: service_healthy');
  });
});
```

### Configuration Validation Tests

```typescript
// tests/unit/core/config/validator.test.ts
import { describe, test, expect } from 'bun:test';
import { ConfigValidator } from '../../../src/core/config/validator';

describe('ConfigValidator', () => {
  const validator = new ConfigValidator();

  test('validates minimal config', () => {
    const config = {
      version: '1.0',
      global: { domain: 'example.com', timezone: 'UTC' },
      services: {},
    };

    const result = validator.validate(config);
    expect(result.valid).toBe(true);
  });

  test('rejects invalid domain', () => {
    const config = {
      version: '1.0',
      global: { domain: 'not a domain', timezone: 'UTC' },
      services: {},
    };

    const result = validator.validate(config);
    expect(result.valid).toBe(false);
    expect(result.errors).toContainEqual(
      expect.objectContaining({ path: 'global.domain' })
    );
  });

  test('validates service dependencies exist', () => {
    const config = {
      version: '1.0',
      global: { domain: 'example.com', timezone: 'UTC' },
      services: {
        zitadel: {
          enabled: true,
          depends_on: ['postgres'], // postgres not defined
        },
      },
    };

    const result = validator.validate(config);
    expect(result.valid).toBe(false);
    expect(result.errors[0].message).toContain('depends_on');
  });

  test('warns on resource over-allocation', () => {
    const config = {
      version: '1.0',
      global: { domain: 'example.com', timezone: 'UTC' },
      services: {
        service1: { enabled: true, resources: { memory: '8g' } },
        service2: { enabled: true, resources: { memory: '8g' } },
      },
    };

    const result = validator.validate(config);
    expect(result.warnings).toContainEqual(
      expect.objectContaining({ type: 'resource-warning' })
    );
  });
});
```

### Health Check Logic Tests

```typescript
// tests/unit/validators/health/http.test.ts
import { describe, test, expect, mock } from 'bun:test';
import { HttpHealthChecker } from '../../../../src/validators/health/http';

describe('HttpHealthChecker', () => {
  test('passes on 200 response', async () => {
    const fetcher = mock(() =>
      Promise.resolve({ ok: true, status: 200 })
    );

    const checker = new HttpHealthChecker({ fetch: fetcher });
    const result = await checker.check({
      url: 'http://localhost:5678/healthz',
      expectedStatus: 200,
    });

    expect(result.status).toBe('pass');
  });

  test('fails on connection error', async () => {
    const fetcher = mock(() =>
      Promise.reject(new Error('Connection refused'))
    );

    const checker = new HttpHealthChecker({ fetch: fetcher });
    const result = await checker.check({
      url: 'http://localhost:5678/healthz',
    });

    expect(result.status).toBe('fail');
    expect(result.message).toContain('Connection refused');
  });

  test('retries on failure', async () => {
    let attempts = 0;
    const fetcher = mock(() => {
      attempts++;
      if (attempts < 3) {
        return Promise.reject(new Error('Temporary failure'));
      }
      return Promise.resolve({ ok: true, status: 200 });
    });

    const checker = new HttpHealthChecker({ fetch: fetcher, retries: 3 });
    const result = await checker.check({ url: 'http://localhost/health' });

    expect(result.status).toBe('pass');
    expect(attempts).toBe(3);
  });
});
```

### Running Unit Tests

```bash
# Run all unit tests
bun test tests/unit

# Run specific test file
bun test tests/unit/generators/docker-compose.test.ts

# Run with coverage
bun test --coverage tests/unit

# Watch mode
bun test --watch tests/unit
```

## 2. Integration Tests

### What to Test

- SSH connection and command execution
- SOPS encryption/decryption with real age keys
- Docker Compose file generation and validation
- Template rendering with real data
- File transfer via SFTP

### SSH Integration Tests

```typescript
// tests/integration/ssh/executor.test.ts
import { describe, test, expect, beforeAll, afterAll } from 'bun:test';
import { SSHClient } from '../../../src/core/ssh/client';
import { startTestSSHServer, stopTestSSHServer } from '../../helpers/ssh-server';

describe('SSHClient Integration', () => {
  let sshServer: TestSSHServer;
  let client: SSHClient;

  beforeAll(async () => {
    // Start a local SSH server for testing
    sshServer = await startTestSSHServer();
    client = new SSHClient({
      host: 'localhost',
      port: sshServer.port,
      username: 'test',
      privateKeyPath: './tests/fixtures/test_key',
    });
    await client.connect();
  });

  afterAll(async () => {
    await client.disconnect();
    await stopTestSSHServer(sshServer);
  });

  test('executes simple command', async () => {
    const result = await client.exec('echo "hello"');
    expect(result.stdout.trim()).toBe('hello');
    expect(result.exitCode).toBe(0);
  });

  test('captures stderr', async () => {
    const result = await client.exec('echo "error" >&2');
    expect(result.stderr.trim()).toBe('error');
  });

  test('handles command failure', async () => {
    const result = await client.exec('exit 42');
    expect(result.exitCode).toBe(42);
  });

  test('respects timeout', async () => {
    const start = Date.now();
    const result = await client.exec('sleep 10', { timeout: 1000 });
    const duration = Date.now() - start;

    expect(result.exitCode).not.toBe(0);
    expect(duration).toBeLessThan(2000);
  });
});
```

### SOPS Integration Tests

```typescript
// tests/integration/secrets/sops.test.ts
import { describe, test, expect, beforeAll } from 'bun:test';
import { SOPSManager } from '../../../src/core/secrets/sops';
import { writeFileSync, unlinkSync } from 'fs';

describe('SOPS Integration', () => {
  const testFile = './tests/fixtures/test-secrets.yaml';
  const encryptedFile = './tests/fixtures/test-secrets.enc.yaml';

  beforeAll(() => {
    // Create test secrets file
    writeFileSync(
      testFile,
      `
postgres:
  password: test-password-123
`
    );
  });

  afterAll(() => {
    unlinkSync(testFile);
    try {
      unlinkSync(encryptedFile);
    } catch {}
  });

  test('encrypts secrets file', async () => {
    const sops = new SOPSManager({
      ageKeyFile: './tests/fixtures/test-age-key.txt',
    });

    await sops.encrypt(testFile, encryptedFile);

    const content = await Bun.file(encryptedFile).text();
    expect(content).toContain('ENC[');
    expect(content).not.toContain('test-password-123');
  });

  test('decrypts secrets file', async () => {
    const sops = new SOPSManager({
      ageKeyFile: './tests/fixtures/test-age-key.txt',
    });

    // Encrypt first
    await sops.encrypt(testFile, encryptedFile);

    // Then decrypt
    const decrypted = await sops.decrypt(encryptedFile);

    expect(decrypted.postgres.password).toBe('test-password-123');
  });
});
```

### Docker Validation Tests

```typescript
// tests/integration/docker/compose-validation.test.ts
import { describe, test, expect } from 'bun:test';
import { DockerComposeGenerator } from '../../../src/generators/docker-compose';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

describe('Docker Compose Validation', () => {
  test('generated compose file is valid', async () => {
    const config = loadTestConfig('./tests/fixtures/services.test.yaml');
    const generator = new DockerComposeGenerator();
    const composeContent = generator.generate(config);

    // Write to temp file
    const tempFile = '/tmp/test-compose.yml';
    await Bun.write(tempFile, composeContent);

    // Validate with docker compose
    const { stderr } = await execAsync(`docker compose -f ${tempFile} config`);
    expect(stderr).toBe('');
  });
});
```

### Running Integration Tests

```bash
# Run integration tests (requires Docker)
bun test tests/integration

# Run with specific test
bun test tests/integration/ssh
```

## 3. End-to-End Tests

### Test Environment

Use Vagrant to spin up a clean Ubuntu VM:

```ruby
# tests/e2e/Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 443, host: 8443

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "8192"
    vb.cpus = 4
    vb.name = "vps-test"
  end

  # Provision with SSH key
  config.vm.provision "shell", inline: <<-SHELL
    mkdir -p /root/.ssh
    echo "#{File.read('tests/fixtures/test_key.pub')}" >> /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
  SHELL
end
```

### E2E Test Scenarios

```typescript
// tests/e2e/provision.test.ts
import { describe, test, expect, beforeAll, afterAll } from 'bun:test';
import { VagrantManager } from '../helpers/vagrant';
import { VPSClient } from '../../src/client';

describe('E2E: Full Provisioning', () => {
  let vagrant: VagrantManager;
  let client: VPSClient;

  beforeAll(async () => {
    vagrant = new VagrantManager('./tests/e2e');
    await vagrant.up();

    client = new VPSClient({
      host: '192.168.56.10',
      user: 'root',
      keyPath: './tests/fixtures/test_key',
      configPath: './tests/fixtures/services.test.yaml',
      secretsPath: './tests/fixtures/secrets.test.enc.yaml',
    });
  }, 300000); // 5 minute timeout for VM startup

  afterAll(async () => {
    await vagrant.destroy();
  });

  test(
    'provisions bare Ubuntu to running state',
    async () => {
      // Run provisioning
      const result = await client.provision({ skipMox: true });
      expect(result.success).toBe(true);

      // Verify Docker is installed
      const dockerVersion = await client.ssh.exec('docker --version');
      expect(dockerVersion.exitCode).toBe(0);
      expect(dockerVersion.stdout).toContain('Docker version');

      // Verify containers are running
      const containers = await client.ssh.exec('docker ps --format "{{.Names}}"');
      expect(containers.stdout).toContain('caddy');
      expect(containers.stdout).toContain('postgres');

      // Verify health checks pass
      const validation = await client.validate();
      expect(validation.status).toBe('pass');
    },
    600000 // 10 minute timeout
  );

  test(
    'deployment updates configuration',
    async () => {
      // Modify configuration
      const newConfig = {
        ...loadTestConfig(),
        services: {
          ...loadTestConfig().services,
          windmill: {
            ...loadTestConfig().services.windmill,
            environment: {
              ...loadTestConfig().services.windmill.environment,
              METRICS_ADDR: '0.0.0.0:8001',
            },
          },
        },
      };

      // Deploy changes
      const result = await client.deploy({ config: newConfig });
      expect(result.success).toBe(true);

      // Verify changes applied
      const envCheck = await client.ssh.exec(
        'docker exec windmill-server printenv METRICS_ADDR'
      );
      expect(envCheck.stdout.trim()).toBe('0.0.0.0:8001');
    },
    120000
  );

  test(
    'rollback restores previous state',
    async () => {
      // Get current state
      const beforeRollback = await client.getState();

      // Make a change
      await client.deploy({ /* some change */ });

      // Rollback
      const result = await client.rollback({ version: beforeRollback.version });
      expect(result.success).toBe(true);

      // Verify state restored
      const afterRollback = await client.getState();
      expect(afterRollback.configHash).toBe(beforeRollback.configHash);
    },
    120000
  );
});
```

### Service Toggle Test

```typescript
// tests/e2e/service-toggle.test.ts
describe('E2E: Service Toggle', () => {
  test('disabling service stops container', async () => {
    // Verify redis is running
    let containers = await client.ssh.exec('docker ps --format "{{.Names}}"');
    expect(containers.stdout).toContain('redis');

    // Disable redis
    const newConfig = {
      ...config,
      services: {
        ...config.services,
        redis: { ...config.services.redis, enabled: false },
      },
    };

    await client.deploy({ config: newConfig });

    // Verify redis is stopped
    containers = await client.ssh.exec('docker ps --format "{{.Names}}"');
    expect(containers.stdout).not.toContain('redis');

    // Verify data volume still exists
    const volumes = await client.ssh.exec('docker volume ls --format "{{.Name}}"');
    expect(volumes.stdout).toContain('redis-data');
  });

  test('re-enabling service starts container with existing data', async () => {
    // Re-enable redis
    const newConfig = {
      ...config,
      services: {
        ...config.services,
        redis: { ...config.services.redis, enabled: true },
      },
    };

    await client.deploy({ config: newConfig });

    // Verify redis is running
    const containers = await client.ssh.exec('docker ps --format "{{.Names}}"');
    expect(containers.stdout).toContain('redis');

    // Verify health check passes
    const health = await client.validate({ service: 'redis' });
    expect(health.status).toBe('pass');
  });
});
```

### Running E2E Tests

```bash
# Start Vagrant VM and run tests
cd tests/e2e
vagrant up
bun test tests/e2e

# Clean up
vagrant destroy -f
```

## Test Fixtures

### services.test.yaml

```yaml
# tests/fixtures/services.test.yaml
version: "1.0"

global:
  domain: test.local
  timezone: UTC

services:
  caddy:
    enabled: true
    type: docker
    image: caddy:2.8-alpine
    ports:
      - host: 80
        container: 80
    volumes:
      - name: caddy-data
        path: /data

  postgres:
    enabled: true
    type: docker
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: "{{ secrets.postgres.root_password }}"
    volumes:
      - name: postgres-data
        path: /var/lib/postgresql/data
    healthcheck:
      type: command
      command: ["pg_isready"]

networks:
  web:
    driver: bridge
```

### secrets.test.yaml

```yaml
# tests/fixtures/secrets.test.yaml (unencrypted for testing)
postgres:
  root_password: test-password-123
zitadel:
  db_password: test-zitadel-password
  masterkey: "12345678901234567890123456789012"
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v1
      - run: bun install
      - run: bun test tests/unit

  integration-tests:
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:dind
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v1
      - run: bun install
      - run: bun test tests/integration

  e2e-tests:
    runs-on: macos-latest  # VirtualBox works on macOS runners
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v1
      - name: Install Vagrant
        run: brew install vagrant virtualbox
      - run: bun install
      - run: |
          cd tests/e2e
          vagrant up
          bun test tests/e2e
          vagrant destroy -f
```

## Coverage Requirements

| Category | Minimum Coverage |
|----------|------------------|
| Unit Tests | 80% |
| Integration Tests | 60% |
| E2E Tests | Key workflows |

## Test Commands Summary

```bash
# All tests
bun test

# Unit tests only
bun test tests/unit

# Integration tests only
bun test tests/integration

# E2E tests only
bun test tests/e2e

# With coverage
bun test --coverage

# Watch mode
bun test --watch

# Specific file
bun test tests/unit/generators/docker-compose.test.ts

# Verbose output
bun test --verbose
```
