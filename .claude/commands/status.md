# Quick Status Overview

Show a brief status of all services and system resources.

## Instructions

Run these commands and present a concise summary:

```bash
# Docker containers
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# System resources
echo "=== Resources ==="
free -h | grep Mem
df -h / | tail -1

# Mox status (one line)
systemctl is-active mox 2>/dev/null || echo "mox: not installed"
```

## Output format

Present as a clean summary:
```
Services:
  caddy:      running (healthy)
  postgres:   running (healthy)
  zitadel:    running
  mox:        active

Resources:
  Memory:     4.2G / 16G used
  Disk:       45G / 512G used
```

$ARGUMENTS
