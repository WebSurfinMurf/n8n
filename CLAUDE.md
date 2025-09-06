# Project: n8n

## Overview
- **Purpose**: Workflow automation platform with visual programming interface
- **URL**: https://n8n.ai-servicers.com
- **Repository**: /home/administrator/projects/n8n
- **Created**: 2025-09-05
- **Version**: 1.109.2
- **Dashy Category**: Automate & Integ (alongside Playwright for automation tools)

## Architecture
n8n deployed in queue mode with separate main and worker containers for scalability:
- **Main Container**: Handles web UI, webhooks, and API
- **Worker Container**: Processes workflow executions
- **Queue System**: Redis-based Bull queue for job distribution

## Configuration
- **Environment File**: /home/administrator/secrets/n8n.env (mode 600)
- **Database**: n8n_db (PostgreSQL)
- **Database User**: n8n_user
- **Container Names**: n8n (main), n8n-worker
- **Data Directory**: /home/administrator/projects/data/n8n

## Services & Ports
- **Application Port**: 5678 (exposed on linuxserver.lan:5678)
- **External Access**: https://n8n.ai-servicers.com (via Traefik)
- **API Access**: http://linuxserver.lan:5678/api/v1
- **PostgreSQL**: postgres:5432 (internal)
- **Redis Queue**: redis:6379 (internal with auth)

## Networking
- **Primary Network**: traefik-proxy (for web access)
- **Database Network**: postgres-net (for PostgreSQL)
- **Cache Network**: redis-net (for Redis queue)

## Deployment
```bash
cd /home/administrator/projects/n8n
./deploy.sh
```

Deploy script handles:
- Container creation (main + worker)
- Network connections
- Data directory setup
- Health checks

## Authentication
Currently using n8n's built-in user management. On first access, you'll be prompted to:
1. Create admin account
2. Set up workspace
3. Configure email settings

### Future Keycloak Integration (TODO)
- Client ID: n8n
- Redirect URI: https://n8n.ai-servicers.com/rest/oauth2/callback
- Will require n8n Enterprise license for SSO features

## Database Details
- **Database**: n8n_db
- **User**: n8n_user  
- **Password**: Stored in /home/administrator/secrets/n8n.env
- **Connection**: postgresql://n8n_user:password@postgres:5432/n8n_db
- **Extensions**: uuid-ossp, pg_trgm, btree_gist

## Redis Configuration
- **Host**: redis
- **Port**: 6379
- **Database**: 0
- **Password**: Authenticated (stored in env)
- **Purpose**: Job queue for workflow executions

## Monitoring & Logs
```bash
# View main container logs
docker logs n8n -f

# View worker logs
docker logs n8n-worker -f

# Check container status
docker ps | grep n8n

# Monitor Redis queue
docker exec redis redis-cli -a $(grep REDIS_PASSWORD /home/administrator/secrets/redis.env | cut -d= -f2) INFO clients
```

## Troubleshooting

### Container Restarting
- Check logs: `docker logs n8n --tail 50`
- Verify database connection: `docker exec n8n nc -zv postgres 5432`
- Check Redis: `docker exec n8n nc -zv redis 6379`

### Database Issues
```bash
# Test database connection (password in /home/administrator/secrets/n8n.env)
source /home/administrator/secrets/n8n.env
PGPASSWORD="${DB_PASSWORD}" psql -h localhost -p 5432 -U n8n_user -d n8n_db -c "SELECT 1;"

# Check database size (admin password in postgres env)
source /home/administrator/secrets/postgres.env
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h localhost -p 5432 -U admin -d postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database WHERE datname = 'n8n_db';"
```

### Permission Issues
- n8n runs as UID 1000 inside container
- Data directory must be writable: `chmod 777 /home/administrator/projects/data/n8n`

### Queue Issues
- Check Redis authentication
- Verify both containers on redis-net network
- Monitor queue: `docker exec n8n-worker npm run queue:health`

## Backup Procedures
```bash
# Database backup
./backupdb.sh n8n_db

# Workflow data backup
tar -czf n8n-workflows-$(date +%Y%m%d).tar.gz /home/administrator/projects/data/n8n

# Environment backup
cp /home/administrator/secrets/n8n.env /home/administrator/secrets/n8n.env.bak
```

## Performance Tuning

### Environment Variables to Consider
```bash
# Enable task runners (future-proofing)
N8N_RUNNERS_ENABLED=true

# Offload manual executions to workers
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

# Security hardening
N8N_BLOCK_ENV_ACCESS_IN_NODE=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
```

### Scaling Options
- Add more worker containers: Duplicate worker deployment with unique names
- Increase worker memory: Adjust Docker resource limits
- Redis persistence: Enable AOF for queue durability

## Integration Points
- **PostgreSQL**: Workflow execution history and metadata
- **Redis**: Execution queue and temporary data
- **SMTP**: Email notifications (via local mailserver)
- **File Storage**: Local filesystem (/home/node/.n8n)
- **Future**: MinIO for S3-compatible storage

## Security Notes
- Admin account creation required on first access
- HTTPS enforced via Traefik
- Database credentials in environment file (mode 600)
- Redis authenticated
- Consider enabling audit logging for production

## Implementation Notes

### 2025-09-05: Initial Deployment
- Created PostgreSQL database with SCRAM-SHA-256 authentication
- Configured queue mode with Redis authentication
- Deployed main and worker containers
- Fixed permission issues with data directory
- Successfully tested web interface access
- Added to Dashy dashboard in new "Automate & Integ" category (with Playwright)
- Exposed port 5678 on linuxserver.lan for API access
- Fixed MCP integration by installing dependencies and updating configuration

### Known Issues
- SSO requires Enterprise license (built-in auth works fine)
- Deprecation warnings for task runners (will address in future update)

## References
- Official Docs: https://docs.n8n.io
- Docker Image: n8nio/n8n:latest
- Community: https://community.n8n.io

---
*Last Updated: 2025-09-05*