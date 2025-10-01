#!/bin/bash
set -e

PROJECT_NAME="n8n"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 Deploying ${PROJECT_NAME}..."

# Load environment
if [ -f "/home/administrator/secrets/${PROJECT_NAME}.env" ]; then
    source /home/administrator/secrets/${PROJECT_NAME}.env
    echo -e "${GREEN}✓${NC} Environment loaded"
else
    echo -e "${RED}✗${NC} Environment file not found"
    exit 1
fi

# Stop existing containers
echo "Stopping existing containers..."
docker stop ${PROJECT_NAME} 2>/dev/null || true
docker stop ${PROJECT_NAME}-worker 2>/dev/null || true
docker rm ${PROJECT_NAME} 2>/dev/null || true
docker rm ${PROJECT_NAME}-worker 2>/dev/null || true

# Pull latest n8n image
echo "Pulling latest n8n image..."
docker pull n8nio/n8n:latest

# Create data directory for n8n with correct ownership
mkdir -p /home/administrator/projects/data/n8n
# n8n runs as UID 1000 inside container, let's use a different approach
# We'll let n8n create its own subdirectory
chmod 777 /home/administrator/projects/data/n8n

# Create networks first
echo "Creating networks if they don't exist..."
docker network create traefik-net 2>/dev/null || true
docker network create postgres-net 2>/dev/null || true
docker network create redis-net 2>/dev/null || true

# Deploy main n8n container (web and webhook processes)
echo "Deploying n8n main container..."
docker run -d \
  --name ${PROJECT_NAME} \
  --restart unless-stopped \
  --network traefik-net \
  --env-file /home/administrator/secrets/${PROJECT_NAME}.env \
  -e N8N_EDITOR_BASE_URL=https://n8n.ai-servicers.com \
  -v /home/administrator/projects/data/n8n:/home/node/.n8n \
  -p 5678:5678 \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.${PROJECT_NAME}.rule=Host(\`${PROJECT_NAME}.ai-servicers.com\`)" \
  --label "traefik.http.routers.${PROJECT_NAME}.entrypoints=websecure" \
  --label "traefik.http.routers.${PROJECT_NAME}.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.${PROJECT_NAME}.loadbalancer.server.port=5678" \
  n8nio/n8n:latest

# Connect to required networks BEFORE container fully starts
echo "Connecting main container to required networks..."
docker network connect postgres-net ${PROJECT_NAME}
docker network connect redis-net ${PROJECT_NAME}

# Deploy worker container for queue mode
echo "Deploying n8n worker container..."
docker run -d \
  --name ${PROJECT_NAME}-worker \
  --restart unless-stopped \
  --network postgres-net \
  --env-file /home/administrator/secrets/${PROJECT_NAME}.env \
  -v /home/administrator/projects/data/n8n:/home/node/.n8n \
  n8nio/n8n:latest \
  worker

# Connect worker to Redis network
echo "Connecting worker to redis-net..."
docker network connect redis-net ${PROJECT_NAME}-worker

# Wait for startup
echo "Waiting for n8n to start..."
sleep 10

# Verify deployment
if docker ps | grep -q ${PROJECT_NAME}; then
    echo -e "${GREEN}✓${NC} Main container running"
else
    echo -e "${RED}✗${NC} Main container failed to start"
    docker logs ${PROJECT_NAME} --tail 50
    exit 1
fi

if docker ps | grep -q ${PROJECT_NAME}-worker; then
    echo -e "${GREEN}✓${NC} Worker container running"
else
    echo -e "${YELLOW}⚠${NC} Worker container not running (optional for single instance)"
fi

# Test database connection
echo "Testing database connection..."
docker exec ${PROJECT_NAME} nc -zv postgres 5432 && echo -e "${GREEN}✓${NC} Database connection successful" || echo -e "${YELLOW}⚠${NC} Database connection failed"

# Test Redis connection
echo "Testing Redis connection..."
docker exec ${PROJECT_NAME} nc -zv redis 6379 && echo -e "${GREEN}✓${NC} Redis connection successful" || echo -e "${YELLOW}⚠${NC} Redis connection failed"

echo ""
echo -e "${GREEN}✅ n8n deployment complete!${NC}"
echo ""
echo "🌐 Access n8n at: https://n8n.ai-servicers.com"
echo "📊 Main container logs: docker logs n8n -f"
echo "⚙️  Worker container logs: docker logs n8n-worker -f"
echo ""
echo "Note: On first access, you'll need to create an admin account."
echo "The system will guide you through the initial setup."