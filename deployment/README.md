# PrixFixe Deployment Infrastructure

This directory contains all deployment-related files for PrixFixe SMTP server.

## Overview

The deployment infrastructure provides:
- Docker containerization with multi-stage builds
- Docker Compose orchestration
- Helper scripts for common operations
- Configuration templates
- Comprehensive documentation

## Quick Start

1. **Ensure Docker is running**:
   ```bash
   docker --version
   docker info
   ```

2. **Build the image**:
   ```bash
   ./scripts/build.sh
   ```

3. **Run the server**:
   ```bash
   ./scripts/run.sh
   ```

4. **Test connectivity**:
   ```bash
   ./scripts/test-smtp.sh
   ```

## File Structure

```
PrixFixe/
├── Dockerfile                 # Multi-stage Docker build
├── .dockerignore             # Docker build exclusions
├── docker-compose.yml        # Compose orchestration
├── .env.example              # Environment variable template
├── DEPLOYMENT.md             # Comprehensive deployment guide
├── scripts/                  # Helper scripts
│   ├── build.sh             # Build Docker image
│   ├── run.sh               # Run container
│   ├── stop.sh              # Stop container
│   ├── logs.sh              # View logs
│   └── test-smtp.sh         # Test SMTP functionality
└── deployment/               # Deployment documentation
    ├── README.md            # This file
    └── TESTING.md           # Testing procedures
```

## Components

### Dockerfile

Multi-stage build optimized for size and security:
- **Builder stage**: Swift 6.0 on Ubuntu 22.04
- **Runtime stage**: Minimal Ubuntu base
- **Final size**: ~180MB
- **Security**: Runs as non-root user (UID 1000)

### docker-compose.yml

Production-ready compose configuration:
- Automatic restart policy
- Resource limits (2 CPU, 2GB RAM)
- Health checks
- Volume mounts for data persistence
- Log rotation
- Network isolation

### Helper Scripts

All scripts are in `scripts/` directory:

#### build.sh
Builds the Docker image with proper tagging and output.

**Usage**:
```bash
./scripts/build.sh
IMAGE_NAME=custom-name ./scripts/build.sh
IMAGE_TAG=v1.0.0 ./scripts/build.sh
```

#### run.sh
Starts the SMTP server in a Docker container with sensible defaults.

**Usage**:
```bash
./scripts/run.sh
SMTP_PORT=2525 SMTP_DOMAIN=mail.example.com ./scripts/run.sh
```

#### stop.sh
Stops the running container.

**Usage**:
```bash
./scripts/stop.sh           # Stop only
./scripts/stop.sh --remove  # Stop and remove
```

#### logs.sh
Views container logs with follow option.

**Usage**:
```bash
./scripts/logs.sh                 # Follow logs
./scripts/logs.sh --no-follow     # Don't follow
./scripts/logs.sh --tail 50       # Last 50 lines
```

#### test-smtp.sh
Tests SMTP connectivity using netcat.

**Usage**:
```bash
./scripts/test-smtp.sh
SMTP_HOST=localhost SMTP_PORT=2525 ./scripts/test-smtp.sh
```

## Configuration

### Environment Variables

Configure via `.env` file or environment variables:

```bash
# Copy template
cp .env.example .env

# Edit configuration
vim .env
```

Available variables:
- `SMTP_DOMAIN`: Server domain name (default: localhost)
- `SMTP_PORT`: External port mapping (default: 2525)
- `SMTP_MAX_CONNECTIONS`: Max concurrent connections (default: 100)
- `SMTP_MAX_MESSAGE_SIZE`: Max message size in bytes (default: 10485760)

### Resource Limits

Configure in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

## Deployment Methods

### Method 1: Docker Compose (Recommended)

```bash
# Start
docker-compose up -d

# Logs
docker-compose logs -f

# Stop
docker-compose down
```

### Method 2: Helper Scripts

```bash
# Build and run
./scripts/build.sh
./scripts/run.sh

# Test
./scripts/test-smtp.sh

# Stop
./scripts/stop.sh
```

### Method 3: Manual Docker Commands

```bash
# Build
docker build -t prixfixe:latest .

# Run
docker run -d \
  --name prixfixe-smtp \
  -p 2525:2525 \
  -e SMTP_DOMAIN=localhost \
  -v ./mail-data:/var/mail \
  prixfixe:latest

# Logs
docker logs -f prixfixe-smtp

# Stop
docker stop prixfixe-smtp
```

## Testing

### Pre-Deployment Testing

1. **Build image**:
   ```bash
   ./scripts/build.sh
   ```

2. **Run container**:
   ```bash
   ./scripts/run.sh
   ```

3. **Test SMTP**:
   ```bash
   ./scripts/test-smtp.sh
   ```

4. **Check logs**:
   ```bash
   ./scripts/logs.sh --no-follow
   ```

### Manual SMTP Testing

Using telnet:
```bash
telnet localhost 2525
EHLO test.example.com
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.com>
DATA
From: sender@example.com
To: recipient@example.com
Subject: Test

Test message
.
QUIT
```

Using netcat:
```bash
{
  echo "EHLO test.example.com"
  sleep 1
  echo "MAIL FROM:<sender@example.com>"
  sleep 1
  echo "RCPT TO:<recipient@example.com>"
  sleep 1
  echo "DATA"
  sleep 1
  echo "Subject: Test"
  echo ""
  echo "Test message"
  echo "."
  sleep 1
  echo "QUIT"
} | nc localhost 2525
```

## Monitoring

### Health Check

```bash
# Container health status
docker inspect --format='{{.State.Health.Status}}' prixfixe-smtp

# Health check logs
docker inspect prixfixe-smtp | jq '.[0].State.Health'
```

### Resource Usage

```bash
# Real-time stats
docker stats prixfixe-smtp

# docker-compose stats
docker-compose stats
```

### Logs

```bash
# Follow all logs
./scripts/logs.sh

# Last 100 lines
./scripts/logs.sh --tail 100 --no-follow

# With timestamps
docker logs --timestamps prixfixe-smtp
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs prixfixe-smtp

# Check if port is in use
lsof -i :2525

# Check Docker daemon
docker info
```

### Can't connect to SMTP

```bash
# Test port
nc -zv localhost 2525

# Check container is running
docker ps | grep prixfixe

# Check port mapping
docker port prixfixe-smtp
```

### Build fails

```bash
# Clean build
docker system prune -a

# Rebuild without cache
docker build --no-cache -t prixfixe:latest .
```

## Production Deployment

See [DEPLOYMENT.md](../DEPLOYMENT.md) for comprehensive production deployment guide including:
- Security hardening
- Performance tuning
- High availability
- Monitoring and alerting
- Backup and recovery
- Kubernetes deployment

## Support

For issues and questions:
- Check [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed documentation
- Review [INTEGRATION.md](../INTEGRATION.md) for API usage
- Open an issue on GitHub
- Check existing issues and discussions

## Version

- **Infrastructure Version**: 1.0.0
- **PrixFixe Version**: 0.1.0
- **Docker Base**: Ubuntu 22.04
- **Swift Version**: 6.0

## License

Same as PrixFixe: MIT License
