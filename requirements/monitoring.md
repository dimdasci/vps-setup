# Health Monitoring and Alerting

## Overview

The monitoring system provides ongoing health surveillance of the VPS infrastructure with email alerts for critical issues. Designed to be lightweight given the VPS resource constraints (~1.25GB RAM headroom).

## Design Principles

1. **Lightweight** - Minimal resource footprint (< 50MB RAM)
2. **No External Dependencies** - Uses existing Mox for email alerts
3. **Self-Healing** - Automatic restart of crashed monitoring daemon
4. **Configurable** - Alert thresholds and check intervals via config
5. **Non-Intrusive** - Doesn't affect service performance

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MONITORING ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐                                                   │
│  │   Monitor    │ ◄─── Lightweight TypeScript daemon                │
│  │   Daemon     │      Runs on VPS as systemd service               │
│  └──────┬───────┘                                                   │
│         │                                                            │
│         │ Periodic checks (configurable interval)                   │
│         ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    HEALTH CHECKS                              │   │
│  │                                                               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │   │
│  │  │ Docker   │ │  HTTP    │ │   TCP    │ │  System  │        │   │
│  │  │Container │ │Endpoint  │ │  Port    │ │ Resource │        │   │
│  │  │  Health  │ │  Check   │ │  Check   │ │  Check   │        │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │   │
│  │                                                               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                      │   │
│  │  │ Systemd  │ │  Cert    │ │   Log    │                      │   │
│  │  │ Service  │ │  Expiry  │ │ Analysis │                      │   │
│  │  │  (Mox)   │ │  Check   │ │  Check   │                      │   │
│  │  └──────────┘ └──────────┘ └──────────┘                      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│         │                                                            │
│         │ Results                                                    │
│         ▼                                                            │
│  ┌──────────────┐                                                   │
│  │    State     │ ◄─── Track check history, alert state            │
│  │   Manager    │      Prevent alert spam (cooldown)                │
│  └──────┬───────┘                                                   │
│         │                                                            │
│         │ On failure or recovery                                    │
│         ▼                                                            │
│  ┌──────────────┐     ┌──────────────┐                              │
│  │    Alert     │────▶│     Mox      │ ◄─── Email via local SMTP   │
│  │   Manager    │     │    SMTP      │                              │
│  └──────────────┘     └──────────────┘                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Health Checks

### Check Categories

| Category | Checks | Interval | Alert Level |
|----------|--------|----------|-------------|
| System Resources | Disk, Memory, CPU | 5 min | WARN/CRITICAL |
| Docker Containers | Status, Health | 1 min | CRITICAL |
| HTTP Endpoints | Response code, latency | 2 min | CRITICAL |
| TCP Ports | Connectivity | 2 min | CRITICAL |
| Certificates | Expiry | 6 hours | WARN |
| Logs | Error patterns | 5 min | WARN |
| Mox Service | Systemd status | 1 min | CRITICAL |

### Check Definitions

```typescript
// src/monitor/checks.ts

export interface Check {
  name: string;
  category: 'system' | 'docker' | 'endpoint' | 'certificate' | 'log' | 'host';
  interval: number; // milliseconds
  timeout: number;
  alertLevel: 'warn' | 'critical';
  check(): Promise<CheckResult>;
}

export interface CheckResult {
  status: 'pass' | 'warn' | 'fail';
  message: string;
  value?: number | string;
  threshold?: number | string;
}
```

### System Resource Checks

```typescript
export const systemChecks: Check[] = [
  {
    name: 'disk-space',
    category: 'system',
    interval: 5 * 60 * 1000, // 5 minutes
    timeout: 10000,
    alertLevel: 'critical',
    async check() {
      const result = await exec("df -h / | awk 'NR==2 {print $5}' | tr -d '%'");
      const usedPercent = parseInt(result.stdout);

      if (usedPercent > 90) {
        return { status: 'fail', message: `Disk ${usedPercent}% full`, value: usedPercent, threshold: 90 };
      }
      if (usedPercent > 80) {
        return { status: 'warn', message: `Disk ${usedPercent}% full`, value: usedPercent, threshold: 80 };
      }
      return { status: 'pass', message: `Disk ${usedPercent}% used`, value: usedPercent };
    },
  },
  {
    name: 'memory-usage',
    category: 'system',
    interval: 5 * 60 * 1000,
    timeout: 10000,
    alertLevel: 'critical',
    async check() {
      const result = await exec("free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'");
      const usedPercent = parseInt(result.stdout);

      if (usedPercent > 95) {
        return { status: 'fail', message: `Memory ${usedPercent}% used`, value: usedPercent, threshold: 95 };
      }
      if (usedPercent > 90) {
        return { status: 'warn', message: `Memory ${usedPercent}% used`, value: usedPercent, threshold: 90 };
      }
      return { status: 'pass', message: `Memory ${usedPercent}% used`, value: usedPercent };
    },
  },
  {
    name: 'cpu-load',
    category: 'system',
    interval: 5 * 60 * 1000,
    timeout: 10000,
    alertLevel: 'warn',
    async check() {
      const loadResult = await exec("cat /proc/loadavg | awk '{print $1}'");
      const cpuResult = await exec("nproc");
      const load = parseFloat(loadResult.stdout);
      const cpus = parseInt(cpuResult.stdout);
      const loadPerCpu = load / cpus;

      if (loadPerCpu > 2) {
        return { status: 'fail', message: `Load ${load} (${loadPerCpu.toFixed(2)}/cpu)`, value: loadPerCpu };
      }
      if (loadPerCpu > 1) {
        return { status: 'warn', message: `Load ${load} (${loadPerCpu.toFixed(2)}/cpu)`, value: loadPerCpu };
      }
      return { status: 'pass', message: `Load ${load}`, value: loadPerCpu };
    },
  },
];
```

### Docker Container Checks

```typescript
export const dockerChecks: Check[] = [
  {
    name: 'containers-running',
    category: 'docker',
    interval: 60 * 1000, // 1 minute
    timeout: 30000,
    alertLevel: 'critical',
    async check() {
      const expected = ['caddy', 'postgres', 'redis', 'zitadel', 'zitadel-login',
                        'windmill-server', 'windmill-worker', 'windmill-lsp',
                        'postfix-relay'];
      const result = await exec('docker ps --format "{{.Names}}"');
      const running = result.stdout.trim().split('\n');

      const missing = expected.filter(e => !running.some(r => r.includes(e)));

      if (missing.length > 0) {
        return { status: 'fail', message: `Missing: ${missing.join(', ')}` };
      }
      return { status: 'pass', message: `All ${expected.length} containers running` };
    },
  },
  {
    name: 'container-restarts',
    category: 'docker',
    interval: 5 * 60 * 1000,
    timeout: 30000,
    alertLevel: 'warn',
    async check() {
      const result = await exec(
        'docker ps -a --format "{{.Names}}:{{.Status}}" | grep -i restarting'
      );

      if (result.stdout.trim()) {
        return { status: 'fail', message: `Restarting: ${result.stdout.trim()}` };
      }
      return { status: 'pass', message: 'No containers restarting' };
    },
  },
];
```

### Endpoint Checks

```typescript
export const endpointChecks: Check[] = [
  {
    name: 'https-fidudoc',
    category: 'endpoint',
    interval: 2 * 60 * 1000,
    timeout: 30000,
    alertLevel: 'critical',
    async check() {
      const start = Date.now();
      try {
        const response = await fetch('https://fidudoc.eu', { signal: AbortSignal.timeout(10000) });
        const latency = Date.now() - start;

        if (!response.ok) {
          return { status: 'fail', message: `HTTP ${response.status}`, value: response.status };
        }
        if (latency > 5000) {
          return { status: 'warn', message: `Slow response: ${latency}ms`, value: latency };
        }
        return { status: 'pass', message: `OK (${latency}ms)`, value: latency };
      } catch (error) {
        return { status: 'fail', message: error.message };
      }
    },
  },
  // Repeat for: auth.fidudoc.eu, wm.fidudoc.eu, mail.fidudoc.eu
];
```

### Certificate Expiry Check

```typescript
export const certificateChecks: Check[] = [
  {
    name: 'cert-expiry',
    category: 'certificate',
    interval: 6 * 60 * 60 * 1000, // 6 hours
    timeout: 60000,
    alertLevel: 'warn',
    async check() {
      const domains = ['fidudoc.eu', 'auth.fidudoc.eu', 'mail.fidudoc.eu'];
      const results: string[] = [];

      for (const domain of domains) {
        const result = await exec(
          `echo | openssl s_client -servername ${domain} -connect ${domain}:443 2>/dev/null | ` +
          `openssl x509 -noout -enddate | cut -d= -f2`
        );
        const expiryDate = new Date(result.stdout.trim());
        const daysUntilExpiry = Math.floor((expiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));

        if (daysUntilExpiry < 3) {
          return { status: 'fail', message: `${domain} expires in ${daysUntilExpiry} days!` };
        }
        if (daysUntilExpiry < 14) {
          results.push(`${domain}: ${daysUntilExpiry}d`);
        }
      }

      if (results.length > 0) {
        return { status: 'warn', message: `Expiring soon: ${results.join(', ')}` };
      }
      return { status: 'pass', message: 'All certificates valid > 14 days' };
    },
  },
];
```

### Mox Host Service Check

```typescript
export const hostChecks: Check[] = [
  {
    name: 'mox-service',
    category: 'host',
    interval: 60 * 1000,
    timeout: 10000,
    alertLevel: 'critical',
    async check() {
      const result = await exec('systemctl is-active mox');
      if (result.stdout.trim() !== 'active') {
        return { status: 'fail', message: `Mox status: ${result.stdout.trim()}` };
      }
      return { status: 'pass', message: 'Mox active' };
    },
  },
  {
    name: 'mox-ports',
    category: 'host',
    interval: 2 * 60 * 1000,
    timeout: 30000,
    alertLevel: 'critical',
    async check() {
      const ports = [25, 465, 587, 993];
      const failed: number[] = [];

      for (const port of ports) {
        const result = await exec(`nc -z -w5 localhost ${port}; echo $?`);
        if (result.stdout.trim() !== '0') {
          failed.push(port);
        }
      }

      if (failed.length > 0) {
        return { status: 'fail', message: `Ports down: ${failed.join(', ')}` };
      }
      return { status: 'pass', message: 'All Mox ports responsive' };
    },
  },
];
```

## Alert System

### Alert Configuration

```yaml
# config/monitoring.yaml
monitoring:
  enabled: true

  # Check intervals (can override defaults)
  intervals:
    system: 300000      # 5 min
    docker: 60000       # 1 min
    endpoint: 120000    # 2 min
    certificate: 21600000  # 6 hours

  # Alert settings
  alerts:
    email:
      enabled: true
      recipients:
        - admin@fidudoc.eu
      from: monitoring@fidudoc.eu
      smtp:
        host: localhost
        port: 587
        secure: false

    # Prevent alert spam
    cooldown:
      initial: 300      # 5 min between first alerts
      repeated: 3600    # 1 hour between repeated alerts
      recovery: 300     # 5 min after recovery before re-alerting

  # Thresholds
  thresholds:
    disk_warn: 80
    disk_critical: 90
    memory_warn: 90
    memory_critical: 95
    cert_warn_days: 14
    cert_critical_days: 3
```

### Alert Manager

```typescript
// src/monitor/alerts/manager.ts

interface AlertState {
  checkName: string;
  status: 'alerting' | 'recovering' | 'ok';
  lastAlertTime: number;
  alertCount: number;
  lastMessage: string;
}

export class AlertManager {
  private state: Map<string, AlertState> = new Map();
  private emailer: EmailAlerter;
  private config: AlertConfig;

  constructor(config: AlertConfig) {
    this.config = config;
    this.emailer = new EmailAlerter(config.email);
  }

  async processResult(checkName: string, result: CheckResult): Promise<void> {
    const current = this.state.get(checkName) || {
      checkName,
      status: 'ok',
      lastAlertTime: 0,
      alertCount: 0,
      lastMessage: '',
    };

    const now = Date.now();

    // Determine if we should alert
    if (result.status === 'fail') {
      if (current.status === 'ok') {
        // New failure - alert immediately
        await this.sendAlert(checkName, result, 'NEW');
        current.status = 'alerting';
        current.lastAlertTime = now;
        current.alertCount = 1;
      } else if (now - current.lastAlertTime > this.config.cooldown.repeated * 1000) {
        // Repeated failure after cooldown
        await this.sendAlert(checkName, result, 'ONGOING');
        current.lastAlertTime = now;
        current.alertCount++;
      }
      current.lastMessage = result.message;
    } else if (result.status === 'pass' && current.status === 'alerting') {
      // Recovery
      await this.sendRecovery(checkName, current.lastMessage);
      current.status = 'ok';
      current.alertCount = 0;
    }

    this.state.set(checkName, current);
  }

  private async sendAlert(checkName: string, result: CheckResult, type: 'NEW' | 'ONGOING'): Promise<void> {
    const subject = `[${type}] VPS Alert: ${checkName}`;
    const body = `
Health Check Alert
==================

Check: ${checkName}
Status: ${result.status.toUpperCase()}
Message: ${result.message}
${result.value ? `Value: ${result.value}` : ''}
${result.threshold ? `Threshold: ${result.threshold}` : ''}

Time: ${new Date().toISOString()}
Server: fidudoc.eu

---
VPS Monitoring System
`;

    await this.emailer.send({
      to: this.config.email.recipients,
      subject,
      body,
    });
  }

  private async sendRecovery(checkName: string, previousMessage: string): Promise<void> {
    const subject = `[RESOLVED] VPS Alert: ${checkName}`;
    const body = `
Health Check Recovered
======================

Check: ${checkName}
Status: RESOLVED
Previous Issue: ${previousMessage}

Time: ${new Date().toISOString()}
Server: fidudoc.eu

---
VPS Monitoring System
`;

    await this.emailer.send({
      to: this.config.email.recipients,
      subject,
      body,
    });
  }
}
```

### Email Alerter

```typescript
// src/monitor/alerts/email.ts

import { createTransport } from 'nodemailer';

export class EmailAlerter {
  private transporter: any;

  constructor(config: EmailConfig) {
    this.transporter = createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.secure,
      // No auth needed for local Mox
    });
  }

  async send(options: { to: string[]; subject: string; body: string }): Promise<void> {
    await this.transporter.sendMail({
      from: `"VPS Monitor" <monitoring@fidudoc.eu>`,
      to: options.to.join(', '),
      subject: options.subject,
      text: options.body,
    });
  }
}
```

## Monitoring Daemon

### Daemon Implementation

```typescript
// src/monitor/daemon.ts

export class MonitorDaemon {
  private checks: Check[] = [];
  private alertManager: AlertManager;
  private timers: Map<string, NodeJS.Timeout> = new Map();
  private running = false;

  constructor(config: MonitoringConfig) {
    this.alertManager = new AlertManager(config.alerts);
    this.checks = [
      ...systemChecks,
      ...dockerChecks,
      ...endpointChecks,
      ...certificateChecks,
      ...hostChecks,
    ];
  }

  start(): void {
    if (this.running) return;
    this.running = true;

    console.log(`Starting monitoring daemon with ${this.checks.length} checks`);

    for (const check of this.checks) {
      this.scheduleCheck(check);
    }
  }

  stop(): void {
    this.running = false;
    for (const timer of this.timers.values()) {
      clearInterval(timer);
    }
    this.timers.clear();
  }

  private scheduleCheck(check: Check): void {
    // Run immediately
    this.runCheck(check);

    // Then schedule periodic runs
    const timer = setInterval(() => this.runCheck(check), check.interval);
    this.timers.set(check.name, timer);
  }

  private async runCheck(check: Check): Promise<void> {
    try {
      const result = await Promise.race([
        check.check(),
        new Promise<CheckResult>((_, reject) =>
          setTimeout(() => reject(new Error('Timeout')), check.timeout)
        ),
      ]);

      await this.alertManager.processResult(check.name, result);

      // Log result
      const icon = result.status === 'pass' ? '✓' : result.status === 'warn' ? '⚠' : '✗';
      console.log(`[${new Date().toISOString()}] ${icon} ${check.name}: ${result.message}`);
    } catch (error) {
      const result: CheckResult = {
        status: 'fail',
        message: `Check error: ${error.message}`,
      };
      await this.alertManager.processResult(check.name, result);
      console.error(`[${new Date().toISOString()}] ✗ ${check.name}: ${error.message}`);
    }
  }
}
```

### Systemd Service

```ini
# /etc/systemd/system/vps-monitor.service

[Unit]
Description=VPS Health Monitor
After=network.target docker.service mox.service
Wants=docker.service

[Service]
Type=simple
User=app
WorkingDirectory=/home/app/docker
ExecStart=/home/app/.bun/bin/bun /home/app/docker/monitor/daemon.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits
MemoryMax=50M
CPUQuota=5%

[Install]
WantedBy=multi-user.target
```

### Daemon Installation

```bash
# Install monitoring daemon
vps monitoring install --host 203.0.113.50

# Start/stop daemon
vps monitoring start --host 203.0.113.50
vps monitoring stop --host 203.0.113.50

# View status
vps monitoring status --host 203.0.113.50

# View daemon logs
vps monitoring logs --host 203.0.113.50 --follow
```

## CLI Integration

### Status Command Enhancement

```bash
# Show monitoring status in overall status
vps status --host 203.0.113.50

# Output includes:
#
# Monitoring:
#   Status: Running
#   Uptime: 3 days
#   Last Check: 30 seconds ago
#   Recent Alerts: 0
#   Checks: 15 passing, 0 warnings, 0 failing
```

### Dedicated Monitoring Command

```bash
# View current check results
vps monitoring status --host 203.0.113.50

# Output:
#
# Health Checks Status
# ====================
#
# System (3/3 passing)
#   ✓ disk-space      42% used
#   ✓ memory-usage    72% used
#   ✓ cpu-load        0.45 (0.08/cpu)
#
# Docker (2/2 passing)
#   ✓ containers-running    All 11 containers running
#   ✓ container-restarts    No containers restarting
#
# Endpoints (6/6 passing)
#   ✓ https://fidudoc.eu        200 OK (234ms)
#   ✓ https://auth.fidudoc.eu   200 OK (156ms)
#   ...
#
# Certificates (1/1 passing)
#   ✓ cert-expiry    All valid > 14 days
#
# Host Services (2/2 passing)
#   ✓ mox-service    Mox active
#   ✓ mox-ports      All ports responsive
```

## Resource Usage

The monitoring daemon is designed to be lightweight:

| Resource | Target | Actual |
|----------|--------|--------|
| Memory | < 50MB | ~30MB |
| CPU | < 5% | ~1% average |
| Disk | < 10MB | ~5MB (logs) |
| Network | Minimal | Local only (except endpoint checks) |

## Alert Examples

### Critical Alert Email

```
Subject: [NEW] VPS Alert: containers-running

Health Check Alert
==================

Check: containers-running
Status: FAIL
Message: Missing: postgres, zitadel

Time: 2025-01-09T14:30:00Z
Server: fidudoc.eu

---
VPS Monitoring System
```

### Recovery Email

```
Subject: [RESOLVED] VPS Alert: containers-running

Health Check Recovered
======================

Check: containers-running
Status: RESOLVED
Previous Issue: Missing: postgres, zitadel

Time: 2025-01-09T14:35:00Z
Server: fidudoc.eu

---
VPS Monitoring System
```

## Troubleshooting

### Daemon Not Starting

```bash
# Check systemd status
systemctl status vps-monitor

# Check logs
journalctl -u vps-monitor -f

# Manual run for debugging
cd /home/app/docker && bun monitor/daemon.ts
```

### Alerts Not Sending

```bash
# Test SMTP connection
echo "Test" | mail -s "Test" admin@fidudoc.eu

# Check Mox is accepting local connections
telnet localhost 587

# Check monitoring logs
journalctl -u vps-monitor | grep -i email
```

### False Positives

Adjust thresholds in `config/monitoring.yaml`:

```yaml
thresholds:
  disk_warn: 85      # Increase from 80
  memory_warn: 92    # Increase from 90
```

Then restart the daemon:

```bash
systemctl restart vps-monitor
```
