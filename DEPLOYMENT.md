# PrixFixe SMTP Server - Deployment Guide

This guide provides comprehensive instructions for deploying PrixFixe SMTP server in production and development environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Docker Deployment](#docker-deployment)
- [Docker Compose Deployment](#docker-compose-deployment)
- [Configuration](#configuration)
- [Helper Scripts](#helper-scripts)
- [Production Deployment](#production-deployment)
- [Monitoring and Logging](#monitoring-and-logging)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

## Quick Start

The fastest way to get PrixFixe running:

```bash
# Clone the repository
git clone https://github.com/yourusername/PrixFixe.git
cd PrixFixe

# Start with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f

# Test the server
./scripts/test-smtp.sh
```

The server will be available at `localhost:2525`.

## Docker Deployment

### Prerequisites

- Docker 20.10 or later
- Linux, macOS, or Windows with WSL2
- At least 2GB RAM available
- 5GB disk space for build

### Building the Image

```bash
# Using the build script (recommended)
./scripts/build.sh

# Or manually
docker build -t prixfixe:latest .
```

The build process uses a multi-stage Dockerfile:
- **Stage 1 (Builder)**: Compiles Swift code on Ubuntu 22.04 with Swift 6.0
- **Stage 2 (Runtime)**: Creates minimal runtime image (~180MB)

### Running the Container

```bash
# Using the run script (recommended)
./scripts/run.sh

# Or manually
docker run -d \
  --name prixfixe-smtp \
  -p 2525:2525 \
  -e SMTP_DOMAIN=localhost \
  -e SMTP_MAX_CONNECTIONS=100 \
  -v ./mail-data:/var/mail \
  prixfixe:latest
```

### Managing the Container

```bash
# View logs
./scripts/logs.sh

# Stop the server
./scripts/stop.sh

# Stop and remove the container
./scripts/stop.sh --remove

# Test SMTP functionality
./scripts/test-smtp.sh
```

## Docker Compose Deployment

Docker Compose provides the easiest deployment experience with all configuration in one place.

### Basic Deployment

1. **Create environment file** (optional):

```bash
cp .env.example .env
# Edit .env with your configuration
```

2. **Start the server**:

```bash
docker-compose up -d
```

3. **Verify it's running**:

```bash
docker-compose ps
docker-compose logs -f prixfixe
```

### Docker Compose Commands

```bash
# Start the server
docker-compose up -d

# View logs
docker-compose logs -f prixfixe

# Stop the server
docker-compose stop

# Stop and remove containers
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# View resource usage
docker-compose stats
```

### Multiple Environments

Create different compose files for different environments:

**docker-compose.dev.yml**:
```yaml
version: '3.8'
services:
  prixfixe:
    build: .
    ports:
      - "2525:2525"
    environment:
      SMTP_DOMAIN: localhost
      SMTP_MAX_CONNECTIONS: 10
```

**docker-compose.prod.yml**:
```yaml
version: '3.8'
services:
  prixfixe:
    image: prixfixe:1.0.0
    ports:
      - "25:2525"
    environment:
      SMTP_DOMAIN: mail.example.com
      SMTP_MAX_CONNECTIONS: 1000
    restart: always
```

Use with:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Configuration

### Environment Variables

Configure the server using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_DOMAIN` | `localhost` | Domain name for SMTP greeting |
| `SMTP_PORT` | `2525` | Internal SMTP port (always 2525 in container) |
| `SMTP_MAX_CONNECTIONS` | `100` | Maximum concurrent connections |
| `SMTP_MAX_MESSAGE_SIZE` | `10485760` | Maximum message size in bytes (10 MB) |

### Configuration Examples

**Development Environment**:
```bash
SMTP_DOMAIN=localhost
SMTP_PORT=2525
SMTP_MAX_CONNECTIONS=10
SMTP_MAX_MESSAGE_SIZE=5242880  # 5 MB
```

**Staging Environment**:
```bash
SMTP_DOMAIN=staging-mail.example.com
SMTP_PORT=2525
SMTP_MAX_CONNECTIONS=50
SMTP_MAX_MESSAGE_SIZE=10485760  # 10 MB
```

**Production Environment**:
```bash
SMTP_DOMAIN=mail.example.com
SMTP_PORT=25
SMTP_MAX_CONNECTIONS=1000
SMTP_MAX_MESSAGE_SIZE=26214400  # 25 MB
```

### Port Configuration

The container always runs on port 2525 internally. You can map this to any external port:

```bash
# Standard SMTP port (requires root/privileges)
docker run -p 25:2525 prixfixe:latest

# Alternative port
docker run -p 2525:2525 prixfixe:latest

# Custom port
docker run -p 8025:2525 prixfixe:latest
```

**Note**: Binding to ports below 1024 on Linux requires root privileges or proper capabilities.

### Volume Mounts

Mount volumes for persistent data:

```bash
# Mail data
-v /path/to/mail:/var/mail

# Logs
-v /path/to/logs:/var/log/prixfixe

# Custom configuration (future)
-v /path/to/config:/etc/prixfixe
```

## Helper Scripts

PrixFixe includes helper scripts in the `scripts/` directory:

### build.sh

Builds the Docker image:

```bash
./scripts/build.sh

# Custom image name
IMAGE_NAME=my-smtp-server ./scripts/build.sh

# Custom tag
IMAGE_TAG=v1.0.0 ./scripts/build.sh
```

### run.sh

Runs the server in a Docker container:

```bash
./scripts/run.sh

# Custom configuration
SMTP_DOMAIN=mail.example.com SMTP_PORT=2525 ./scripts/run.sh

# Custom container name
CONTAINER_NAME=my-smtp ./scripts/run.sh
```

### stop.sh

Stops the server:

```bash
# Stop only
./scripts/stop.sh

# Stop and remove
./scripts/stop.sh --remove
```

### logs.sh

Views server logs:

```bash
# Follow logs (default)
./scripts/logs.sh

# Don't follow
./scripts/logs.sh --no-follow

# Show last 50 lines
./scripts/logs.sh --tail 50
```

### test-smtp.sh

Tests SMTP connectivity:

```bash
./scripts/test-smtp.sh

# Test different host/port
SMTP_HOST=mail.example.com SMTP_PORT=25 ./scripts/test-smtp.sh
```

## Production Deployment

### System Requirements

**Minimum**:
- 1 CPU core
- 512 MB RAM
- 1 GB disk space
- Docker 20.10+

**Recommended**:
- 2-4 CPU cores
- 2-4 GB RAM
- 10+ GB disk space
- Docker 20.10+

### Production Checklist

- [ ] Configure appropriate resource limits
- [ ] Set up log rotation
- [ ] Configure restart policy
- [ ] Set up monitoring and alerts
- [ ] Configure firewall rules
- [ ] Set up backup for mail data
- [ ] Document incident response procedures
- [ ] Test disaster recovery

### Resource Limits

Configure resource limits in docker-compose.yml:

```yaml
services:
  prixfixe:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

Or when running manually:

```bash
docker run -d \
  --cpus="2.0" \
  --memory="2g" \
  --memory-reservation="512m" \
  prixfixe:latest
```

### Restart Policy

Always configure a restart policy for production:

```bash
docker run -d --restart unless-stopped prixfixe:latest
```

Options:
- `no`: Never restart
- `on-failure`: Restart only on failure
- `always`: Always restart
- `unless-stopped`: Restart unless manually stopped

### Firewall Configuration

Open the SMTP port in your firewall:

**UFW (Ubuntu)**:
```bash
sudo ufw allow 2525/tcp
sudo ufw status
```

**firewalld (RHEL/CentOS)**:
```bash
sudo firewall-cmd --permanent --add-port=2525/tcp
sudo firewall-cmd --reload
```

**iptables**:
```bash
sudo iptables -A INPUT -p tcp --dport 2525 -j ACCEPT
```

## Monitoring and Logging

### Health Checks

The container includes a built-in health check:

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' prixfixe-smtp
```

Health check runs every 30 seconds and verifies the process is running.

### Viewing Logs

```bash
# Docker logs
docker logs -f prixfixe-smtp

# docker-compose logs
docker-compose logs -f prixfixe

# Using helper script
./scripts/logs.sh
```

### Log Rotation

Configure log rotation in docker-compose.yml:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

Or with Docker run:

```bash
docker run -d \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  prixfixe:latest
```

### External Log Aggregation

Send logs to external systems:

**Syslog**:
```yaml
logging:
  driver: syslog
  options:
    syslog-address: "tcp://192.168.0.42:514"
```

**Fluentd**:
```yaml
logging:
  driver: fluentd
  options:
    fluentd-address: localhost:24224
```

### Container Metrics

Monitor container resource usage:

```bash
# Real-time stats
docker stats prixfixe-smtp

# docker-compose stats
docker-compose stats
```

## Security

### Running as Non-Root

The container runs as a non-root user (`smtp`, UID 1000) by default for security.

### Security Options

Enable additional security features:

```bash
docker run -d \
  --security-opt=no-new-privileges:true \
  --read-only \
  --tmpfs /tmp \
  prixfixe:latest
```

Or in docker-compose.yml:

```yaml
security_opt:
  - no-new-privileges:true
read_only: true
tmpfs:
  - /tmp
```

### Network Security

Use Docker networks for isolation:

```bash
# Create dedicated network
docker network create smtp-network

# Run in network
docker run -d --network smtp-network prixfixe:latest
```

### Secrets Management

Use Docker secrets for sensitive data:

```bash
# Create secret
echo "sensitive-config" | docker secret create smtp_config -

# Use in service
docker service create \
  --secret smtp_config \
  prixfixe:latest
```

### Security Scanning

Scan the image for vulnerabilities:

```bash
# Using Docker Scout
docker scout cves prixfixe:latest

# Using Trivy
trivy image prixfixe:latest
```

## Troubleshooting

### Container Won't Start

**Check logs**:
```bash
docker logs prixfixe-smtp
```

**Common issues**:
- Port already in use: Change the external port mapping
- Permission denied: Check volume mount permissions
- Out of memory: Increase memory limits

### Port Already in Use

Find what's using the port:

```bash
# Linux/macOS
sudo lsof -i :2525

# Alternative
sudo netstat -tlnp | grep 2525
```

Kill the process or use a different port.

### Connection Refused

**Check firewall**:
```bash
# Test port accessibility
telnet localhost 2525
nc -zv localhost 2525
```

**Check container is running**:
```bash
docker ps | grep prixfixe
```

**Check port mapping**:
```bash
docker port prixfixe-smtp
```

### High Memory Usage

**Check current usage**:
```bash
docker stats prixfixe-smtp
```

**Reduce limits**:
```yaml
environment:
  SMTP_MAX_CONNECTIONS: 50
  SMTP_MAX_MESSAGE_SIZE: 5242880
```

### Messages Not Being Processed

**Check logs for errors**:
```bash
./scripts/logs.sh
```

**Verify SMTP conversation**:
```bash
./scripts/test-smtp.sh
```

**Check mail directory**:
```bash
docker exec prixfixe-smtp ls -la /var/mail
```

### Container Keeps Restarting

**Check restart count**:
```bash
docker inspect prixfixe-smtp | grep RestartCount
```

**Disable restart policy temporarily**:
```bash
docker update --restart=no prixfixe-smtp
```

**Check for crash loops**:
```bash
docker logs --tail 100 prixfixe-smtp
```

## Advanced Topics

### Building for Multiple Architectures

Build for ARM64 (Apple Silicon, ARM servers):

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t prixfixe:latest \
  --push \
  .
```

### Custom Builds

Customize the build process:

```bash
# Different Swift version
docker build --build-arg SWIFT_VERSION=6.0 -t prixfixe:latest .

# Different base image
docker build --build-arg BASE_IMAGE=ubuntu:23.04 -t prixfixe:latest .
```

### Docker Swarm Deployment

Deploy as a Docker Swarm service:

```bash
docker service create \
  --name prixfixe \
  --replicas 3 \
  --publish 2525:2525 \
  prixfixe:latest
```

### Using with Reverse Proxy

Example nginx configuration:

```nginx
stream {
    upstream smtp_backend {
        server localhost:2525;
    }

    server {
        listen 25;
        proxy_pass smtp_backend;
        proxy_timeout 300s;
    }
}
```

### Kubernetes Deployment (Future)

Basic Kubernetes deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prixfixe-smtp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prixfixe
  template:
    metadata:
      labels:
        app: prixfixe
    spec:
      containers:
      - name: prixfixe
        image: prixfixe:latest
        ports:
        - containerPort: 2525
        env:
        - name: SMTP_DOMAIN
          value: mail.example.com
        - name: SMTP_MAX_CONNECTIONS
          value: "1000"
---
apiVersion: v1
kind: Service
metadata:
  name: prixfixe-smtp
spec:
  selector:
    app: prixfixe
  ports:
  - port: 25
    targetPort: 2525
  type: LoadBalancer
```

### Performance Tuning

Optimize for high-throughput scenarios:

```yaml
environment:
  SMTP_MAX_CONNECTIONS: 1000
  SMTP_MAX_MESSAGE_SIZE: 26214400

deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 4G

ulimits:
  nofile:
    soft: 65536
    hard: 65536
```

### Backup and Restore

**Backup mail data**:
```bash
# Using Docker volume
docker run --rm \
  -v prixfixe_mail-data:/data \
  -v $(pwd)/backup:/backup \
  ubuntu tar czf /backup/mail-backup-$(date +%Y%m%d).tar.gz /data

# Using host directory
tar czf mail-backup-$(date +%Y%m%d).tar.gz ./mail-data
```

**Restore mail data**:
```bash
# Stop the server
docker-compose stop

# Restore data
docker run --rm \
  -v prixfixe_mail-data:/data \
  -v $(pwd)/backup:/backup \
  ubuntu tar xzf /backup/mail-backup-20251127.tar.gz -C /

# Restart the server
docker-compose start
```

## Getting Help

If you encounter issues:

1. Check this deployment guide
2. Review the [Integration Guide](INTEGRATION.md)
3. Check logs: `./scripts/logs.sh`
4. Test connectivity: `./scripts/test-smtp.sh`
5. Search [GitHub Issues](https://github.com/yourusername/PrixFixe/issues)
6. Open a new issue with:
   - PrixFixe version
   - Docker version
   - Platform (Linux distro, macOS version)
   - Complete error messages
   - Steps to reproduce

## Additional Resources

- [Integration Guide](INTEGRATION.md) - Using PrixFixe in your application
- [README](README.md) - Project overview and features
- [CHANGELOG](CHANGELOG.md) - Version history
- [Docker Documentation](https://docs.docker.com/)
- [RFC 5321 - SMTP](https://tools.ietf.org/html/rfc5321)

---

**Version**: 0.1.0
**Last Updated**: 2025-11-27

For questions and support, please open an issue on [GitHub](https://github.com/yourusername/PrixFixe/issues).
