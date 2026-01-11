# View Service Logs

Show logs for a specific service or all services.

## Instructions

1. If service name provided, show logs for that service
2. If no service specified, show recent logs for all services
3. Use `--tail 100` by default to avoid overwhelming output
4. For Mox (host service), use `journalctl -u mox`

## Commands

```bash
# Docker services
docker compose logs --tail 100 -f <service>

# Mox email server
sudo journalctl -u mox -f --lines 100

# All services overview
docker compose logs --tail 50
```

## Common services

- `caddy` - Reverse proxy
- `postgres` - Database
- `zitadel` - Identity provider
- `windmill-server` - Workflow engine
- `windmill-worker` - Workflow workers

$ARGUMENTS
