# PrixFixe Docker Deployment - Quick Reference

One-page reference for common operations.

## Quick Start

```bash
# Clone and start
git clone https://github.com/yourusername/PrixFixe.git
cd PrixFixe
docker-compose up -d

# Test
./scripts/test-smtp.sh

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

## Common Commands

### Docker Compose

```bash
docker-compose up -d              # Start in background
docker-compose down               # Stop and remove
docker-compose logs -f prixfixe   # Follow logs
docker-compose ps                 # Show status
docker-compose restart prixfixe   # Restart service
docker-compose build              # Rebuild image
docker-compose up -d --build      # Rebuild and start
```

### Helper Scripts

```bash
./scripts/build.sh                # Build Docker image
./scripts/run.sh                  # Run container
./scripts/stop.sh                 # Stop container
./scripts/stop.sh --remove        # Stop and remove
./scripts/logs.sh                 # Follow logs
./scripts/logs.sh --no-follow     # Don't follow
./scripts/logs.sh --tail 50       # Last 50 lines
./scripts/test-smtp.sh            # Test SMTP
```

### Direct Docker

```bash
# Build
docker build -t prixfixe:latest .

# Run
docker run -d --name prixfixe-smtp -p 2525:2525 prixfixe:latest

# Logs
docker logs -f prixfixe-smtp

# Stop
docker stop prixfixe-smtp

# Remove
docker rm prixfixe-smtp

# Shell access
docker exec -it prixfixe-smtp /bin/bash
```

## Configuration

### Environment Variables

```bash
SMTP_DOMAIN=localhost          # Server domain
SMTP_PORT=2525                 # External port
SMTP_MAX_CONNECTIONS=100       # Max connections
SMTP_MAX_MESSAGE_SIZE=10485760 # Max size (bytes)
```

### Using .env File

```bash
cp .env.example .env
vim .env                       # Edit configuration
docker-compose up -d           # Apply changes
```

### Custom Configuration

```bash
SMTP_DOMAIN=mail.example.com SMTP_PORT=2525 ./scripts/run.sh
```

## Testing

### Automated Test

```bash
./scripts/test-smtp.sh
```

### Manual Test (telnet)

```bash
telnet localhost 2525
EHLO test.example.com
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test
[blank line]
Test message
.
QUIT
```

### Manual Test (netcat)

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

### Check Status

```bash
docker ps | grep prixfixe                    # Running?
docker inspect prixfixe-smtp | grep Status  # Detailed status
docker-compose ps                            # All services
```

### Health Check

```bash
docker inspect --format='{{.State.Health.Status}}' prixfixe-smtp
```

### Resource Usage

```bash
docker stats prixfixe-smtp --no-stream
docker-compose stats
```

### View Logs

```bash
docker logs prixfixe-smtp                    # All logs
docker logs -f prixfixe-smtp                 # Follow
docker logs --tail 100 prixfixe-smtp         # Last 100
docker logs --since 10m prixfixe-smtp        # Last 10 min
docker logs --timestamps prixfixe-smtp       # With timestamps
```

## Troubleshooting

### Container Won't Start

```bash
docker logs prixfixe-smtp                    # Check logs
docker inspect prixfixe-smtp                 # Inspect
docker events --filter container=prixfixe-smtp  # Events
```

### Port Already in Use

```bash
lsof -i :2525                                # What's using port?
SMTP_PORT=8025 ./scripts/run.sh              # Use different port
```

### Can't Connect

```bash
nc -zv localhost 2525                        # Test port
docker port prixfixe-smtp                    # Check mapping
docker exec prixfixe-smtp netstat -tlnp      # Check listening
```

### High Memory

```bash
docker stats prixfixe-smtp                   # Check usage
docker update --memory="1g" prixfixe-smtp    # Update limit
```

### Restart Container

```bash
docker restart prixfixe-smtp
docker-compose restart prixfixe
```

### Reset Everything

```bash
docker-compose down                          # Stop
docker rm prixfixe-smtp                      # Remove container
docker rmi prixfixe:latest                   # Remove image
./scripts/build.sh                           # Rebuild
./scripts/run.sh                             # Restart
```

## Maintenance

### Update Image

```bash
git pull                                     # Get updates
docker-compose down                          # Stop
docker-compose build                         # Rebuild
docker-compose up -d                         # Start
```

### Backup Mail Data

```bash
# Using docker-compose volumes
docker run --rm \
  -v prixfixe_mail-data:/data \
  -v $(pwd)/backup:/backup \
  ubuntu tar czf /backup/mail-$(date +%Y%m%d).tar.gz /data

# Using host directory
tar czf mail-backup-$(date +%Y%m%d).tar.gz ./mail-data
```

### Clean Up

```bash
docker system prune                          # Clean unused
docker volume prune                          # Clean volumes
docker image prune                           # Clean images
```

## File Locations

```
PrixFixe/
├── Dockerfile              # Image definition
├── docker-compose.yml      # Orchestration
├── .env.example            # Config template
├── .dockerignore           # Build exclusions
├── DEPLOYMENT.md           # Full guide
├── scripts/                # Helper scripts
│   ├── build.sh           # Build image
│   ├── run.sh             # Run container
│   ├── stop.sh            # Stop container
│   ├── logs.sh            # View logs
│   └── test-smtp.sh       # Test SMTP
├── deployment/             # Documentation
│   ├── README.md          # Overview
│   ├── TESTING.md         # Testing guide
│   ├── DOCKER-READY.md    # Readiness check
│   └── QUICK-REFERENCE.md # This file
└── mail-data/              # Mail storage (created)
```

## Port Reference

| Port | Description | Usage |
|------|-------------|-------|
| 25 | Standard SMTP | Production (requires root) |
| 587 | Submission | Alternative (requires root) |
| 2525 | Alternative | Development/non-privileged |
| 8025 | Custom | Any non-privileged port |

## Resource Defaults

| Resource | Default | Production |
|----------|---------|------------|
| CPU Limit | 2.0 cores | Adjust per load |
| Memory Limit | 2 GB | Adjust per load |
| CPU Reserve | 0.5 cores | Minimum |
| Memory Reserve | 512 MB | Minimum |
| Max Connections | 100 | Tune per use case |
| Max Message Size | 10 MB | Tune per use case |

## Environment Examples

### Development
```bash
SMTP_DOMAIN=localhost
SMTP_PORT=2525
SMTP_MAX_CONNECTIONS=10
SMTP_MAX_MESSAGE_SIZE=5242880
```

### Staging
```bash
SMTP_DOMAIN=staging-mail.example.com
SMTP_PORT=2525
SMTP_MAX_CONNECTIONS=50
SMTP_MAX_MESSAGE_SIZE=10485760
```

### Production
```bash
SMTP_DOMAIN=mail.example.com
SMTP_PORT=25
SMTP_MAX_CONNECTIONS=1000
SMTP_MAX_MESSAGE_SIZE=26214400
```

## Quick Links

- [Full Deployment Guide](../DEPLOYMENT.md)
- [Integration Guide](../INTEGRATION.md)
- [Testing Guide](TESTING.md)
- [Main README](../README.md)
- [Changelog](../CHANGELOG.md)

## Getting Help

1. Check logs: `./scripts/logs.sh`
2. Test connectivity: `./scripts/test-smtp.sh`
3. Review [DEPLOYMENT.md](../DEPLOYMENT.md) troubleshooting
4. Check [GitHub Issues](https://github.com/yourusername/PrixFixe/issues)
5. Open new issue with logs and details

---

**Version**: 1.0.0 | **Updated**: 2025-11-27
