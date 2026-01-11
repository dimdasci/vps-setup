# Health Check All Services

Run comprehensive health checks on all VPS services.

## Instructions

Check each service category and report status:

### 1. Docker Services
```bash
docker compose ps
docker stats --no-stream
```

### 2. Caddy (Reverse Proxy)
```bash
curl -s -o /dev/null -w "%{http_code}" https://localhost/health 2>/dev/null || echo "Check Caddy"
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
```

### 3. PostgreSQL
```bash
docker exec postgres pg_isready -U postgres
```

### 4. Mox Email Server
```bash
sudo systemctl status mox --no-pager
curl -s http://localhost:8080/ > /dev/null && echo "Mox web: OK" || echo "Mox web: FAIL"
```

### 5. Certificates
```bash
# Check cert expiry for main domain
echo | openssl s_client -servername DOMAIN -connect DOMAIN:443 2>/dev/null | openssl x509 -noout -dates
```

### 6. Disk Space
```bash
df -h /
```

### 7. Memory
```bash
free -h
```

## Output format

Provide a summary table of all services with status (OK/WARN/FAIL).

$ARGUMENTS
