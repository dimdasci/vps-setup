# Windmill Troubleshooting

## Common Issues

### Workers Not Processing Jobs

**Symptom**: Jobs stay in queue, never execute

**Diagnosis**:
```bash
docker compose logs -f windmill-worker
docker compose ps
```

**Causes**:

1. **Worker not connected to database**:
   ```bash
   docker compose exec windmill-worker env | grep DATABASE_URL
   ```

2. **Worker group mismatch**: Check WORKER_GROUP matches job requirements

3. **All workers busy**: Scale up workers
   ```yaml
   deploy:
     replicas: 4
   ```

### Server Health Check Failing

**Symptom**: Container keeps restarting

**Diagnosis**:
```bash
docker compose logs windmill-server
curl http://localhost:8000/api/version
```

**Causes**:

1. **Database not ready**: Ensure PostgreSQL is healthy first
   ```bash
   docker exec postgres pg_isready
   ```

2. **Invalid DATABASE_URL**: Check format
   ```
   postgres://user:password@host:5432/database
   ```

3. **Port conflict**: Check port 8000 is free
   ```bash
   ss -tlnp | grep 8000
   ```

### Custom Tools Not Available

**Symptom**: `pdftotext: command not found`

**Causes**:

1. **Using base image instead of custom**: Check image name
   ```bash
   docker compose exec windmill-worker cat /etc/os-release
   docker compose exec windmill-worker which pdftotext
   ```

2. **Image not rebuilt**: Rebuild after Dockerfile changes
   ```bash
   docker compose build windmill-worker
   docker compose up -d windmill-worker
   ```

3. **Wrong service**: Ensure job runs on worker with custom tools

### Memory Issues

**Symptom**: Worker crashes during image processing

**Causes**:

1. **Image too large**: libvips handles large images well, but check limits
   ```bash
   docker stats windmill-worker
   ```

2. **Memory limit too low**: Increase in docker-compose.yml
   ```yaml
   mem_limit: 2g
   ```

3. **Too many parallel jobs**: Reduce NUM_WORKERS per container

### Docker Socket Permission Denied

**Symptom**: Job containers fail to spawn

**Diagnosis**:
```bash
docker compose exec windmill-worker ls -la /var/run/docker.sock
```

**Solution**: Ensure socket is mounted:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

### LSP Not Working

**Symptom**: No autocomplete in editor

**Diagnosis**:
```bash
docker compose logs windmill-lsp
docker compose ps windmill-lsp
```

**Causes**:

1. **LSP container not running**: Start it
   ```bash
   docker compose up -d windmill-lsp
   ```

2. **Network isolation**: Ensure LSP on same network as server

### Script Timeout

**Symptom**: Jobs killed after timeout

**Solution**: Increase timeout in worker config:
```bash
TIMEOUT_WAIT_RESULT=21600  # 6 hours
```

Or per-script in Windmill UI settings.

## Verification Commands

### Service Status

```bash
# All services
docker compose ps

# Specific health
docker inspect windmill-server | jq '.[0].State.Health'

# API health
curl http://localhost:8000/api/version
```

### Worker Tools

```bash
# Verify custom tools
docker compose exec windmill-worker pdfcpu version
docker compose exec windmill-worker pdfinfo -v
docker compose exec windmill-worker vips --version

# Test PDF extraction
docker compose exec windmill-worker pdftotext /path/to/test.pdf -
```

### Database

```bash
# PostgreSQL health
docker exec postgres pg_isready

# Check Windmill tables
docker exec postgres psql -U windmill -d windmill -c "\dt"

# Database size
docker exec postgres psql -U windmill -d windmill -c "SELECT pg_size_pretty(pg_database_size('windmill'));"
```

### Network

```bash
# Check network connectivity
docker compose exec windmill-worker curl -s http://windmill-server:8000/api/version

# DNS resolution
docker compose exec windmill-worker nslookup postgres
```

## Log Analysis

### View Logs

```bash
# Server logs
docker compose logs -f windmill-server

# Worker logs
docker compose logs -f windmill-worker

# All logs
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100 windmill-server
```

### Filter Errors

```bash
docker compose logs windmill-server 2>&1 | grep -i error
docker compose logs windmill-worker 2>&1 | grep -i "failed\|error"
```

### Job-Specific Logs

Jobs are logged in Windmill UI:
1. Go to Runs
2. Click on specific job
3. View stdout/stderr

## Performance Tuning

### Worker Scaling

```yaml
# More workers for parallel jobs
deploy:
  replicas: 4
```

### Memory Optimization

For large PDF/image processing:
```yaml
mem_limit: 2g  # Per worker
cpus: 1.5
```

### Database Connection Pool

In PostgreSQL:
```sql
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '512MB';
```

## Recovery Procedures

### Restart All Services

```bash
docker compose down
docker compose up -d
```

### Clear Job Queue

In Windmill UI: Settings → Clear Queue

Or via database (careful!):
```sql
DELETE FROM job WHERE status = 'pending';
```

### Reset to Clean State

```bash
docker compose down -v  # Warning: deletes all data
docker compose up -d
```

### Update Windmill

```bash
docker compose pull
docker compose up -d
```

## Official Documentation

- Troubleshooting: https://www.windmill.dev/docs/misc/guides/troubleshoot
- Self-Host FAQ: https://www.windmill.dev/docs/advanced/self_host#faq
- Worker Groups: https://www.windmill.dev/docs/core_concepts/worker_groups
