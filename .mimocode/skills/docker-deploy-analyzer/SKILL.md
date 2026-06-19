---
name: docker-deploy-analyzer
description: Analyzes Docker Compose deployment configurations for a Java microservices project. Reads compose files, environment configs, Nacos service configs, nginx routing, and SQL init scripts to produce a comprehensive deployment analysis with port mappings, service dependencies, and potential issues.
---

# Docker Deployment Analyzer

Systematically analyze a Docker-based microservices deployment. This skill reads configuration files in a specific order to build a complete picture of the deployment architecture.

## When to use

- User asks to analyze or review the Docker deployment setup
- User wants to understand service ports, dependencies, or networking
- User asks "how is this deployed" or "what services are there"
- Before making changes to docker-compose or deployment configs

## Procedure

### Step 1: Discover compose files

Read the `docker/` directory to find all `docker-compose.*.yml` files. Note the naming convention — these are typically split by concern (base, data services, application services, gateway).

### Step 2: Read compose files in order

Read each compose file in dependency order:

1. **Base/common** (`docker-compose.base.yml`) — shared networks, volumes, base configs
2. **Data services** (`docker-compose.data.yml`) — MySQL, Redis, Elasticsearch, MongoDB, etc.
3. **Application services** (`docker-compose.extend.yml`) — microservice containers (admin, portal, auth, search, etc.)
4. **Gateway** (`docker-compose.gateway.yml`) — API gateway / routing layer

For each file, extract:
- Service names and images
- Port mappings (host:container)
- Environment variables and config references
- Volume mounts
- Network assignments
- Health checks
- Dependencies (depends_on)

### Step 3: Read environment config

Read `docker/.env` (or `.env.example` if `.env` is gitignored) for:
- Version variables used in compose files
- Port offsets or customizations
- Password/credential references (note: do not expose secrets)
- Network configuration

### Step 4: Read Dockerfile

Read `docker/Dockerfile.module` (or similar) to understand:
- Base image and JDK version
- Build stages
- Entry point / startup command

### Step 5: Analyze Nacos service configs

Read `docker/nacos-config/` directory:
- List all `*-prod.yaml` files — these define runtime config per service
- For each config file, extract: server port, datasource connections, middleware addresses
- Read `import-config.sh` to understand how configs are imported into Nacos
- Read `verify-config.sh` if present, to understand config validation

### Step 6: Analyze nginx routing

Read `docker/nginx/nginx.conf` (or included configs) for:
- Upstream definitions (which services are behind the reverse proxy)
- Location blocks and routing rules
- SSL/TLS configuration
- Static file serving

### Step 7: Check SQL init scripts

Read `docker/sql/init/` directory for:
- Database initialization scripts
- Schema creation order
- Seed data

### Step 8: Cross-reference and produce analysis

Synthesize findings into a structured report:

```markdown
## Deployment Architecture Summary

### Services and Ports
| Service | Image | Host Port | Container Port | Purpose |
|---------|-------|-----------|----------------|---------|
| ...     | ...   | ...       | ...            | ...     |

### Service Dependencies
- app-service → MySQL, Redis
- gateway → app-service, Nacos
- ...

### Network Topology
- Bridge network: mall-swarm-net
- ...

### Configuration Management
- Nacos: centralizes runtime config for each service
- Config import: via import-config.sh

### Potential Issues
- Port conflicts, missing health checks, hardcoded values, etc.
```

## Stopping condition

Report is complete when all compose files, env config, Nacos configs, nginx config, and SQL init scripts have been read and cross-referenced.

## Notes

- Some files may be large; read with `limit` if needed and focus on key sections (services, ports, volumes, networks)
- If a file is missing, note it as a gap rather than skipping
- The `.env` file may contain secrets — reference variable names, not values
- This skill is tuned for the mall-swarm project structure but the procedure generalizes to similar Spring Cloud microservices deployments
