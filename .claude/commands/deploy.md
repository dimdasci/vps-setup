# Deploy Services

Deploy or redeploy Docker services on the VPS.

## Instructions

1. Check current status with `docker compose ps`
2. Pull latest images if needed: `docker compose pull`
3. Deploy with: `docker compose up -d`
4. Verify deployment: `docker compose ps` and check logs
5. Run health checks on critical services

## Default paths

- Docker Compose: `/home/app/docker/docker-compose.yml`
- Caddyfile: `/home/app/docker/caddy/Caddyfile`
- Environment: `/home/app/docker/.env`

## Safety checks

- Always check `git status` before deploying
- Validate Caddyfile: `docker exec caddy caddy validate --config /etc/caddy/Caddyfile`
- Review changes in docker-compose.yml before applying

$ARGUMENTS
