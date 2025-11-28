# PrixFixe Docker Deployment - Testing Guide

This guide outlines the testing procedures for verifying the Docker deployment infrastructure.

## Testing Checklist

Use this checklist to verify the deployment is working correctly:

### Pre-Deployment Checks

- [ ] Docker is installed and running
- [ ] Docker version is 20.10 or later
- [ ] Sufficient disk space (5GB minimum)
- [ ] Port 2525 is available (or chosen port)
- [ ] User has Docker permissions

### Build Phase Tests

- [ ] Dockerfile builds without errors
- [ ] Multi-stage build completes successfully
- [ ] Final image size is reasonable (~180MB)
- [ ] Image includes all necessary files
- [ ] Security scan shows no critical vulnerabilities

### Runtime Tests

- [ ] Container starts successfully
- [ ] Container runs as non-root user
- [ ] Health check passes
- [ ] Server listens on correct port
- [ ] Logs are accessible
- [ ] Container survives restart

### Functionality Tests

- [ ] SMTP greeting received
- [ ] EHLO command works
- [ ] MAIL FROM command works
- [ ] RCPT TO command works
- [ ] DATA command works
- [ ] Message acceptance works
- [ ] QUIT command works
- [ ] Multiple connections work
- [ ] Large messages are handled
- [ ] Connection timeouts work

### Configuration Tests

- [ ] Environment variables are respected
- [ ] Port mapping works correctly
- [ ] Volume mounts work
- [ ] Resource limits are enforced
- [ ] Restart policy works

### Helper Scripts Tests

- [ ] build.sh completes successfully
- [ ] run.sh starts container
- [ ] stop.sh stops container
- [ ] logs.sh shows logs
- [ ] test-smtp.sh validates connectivity

## Detailed Testing Procedures

### 1. Pre-Deployment Verification

```bash
# Verify Docker installation
docker --version
# Expected: Docker version 20.10.0 or later

# Verify Docker is running
docker info
# Expected: Server information displayed

# Check available disk space
df -h
# Expected: At least 5GB free

# Check port availability
lsof -i :2525
# Expected: No output (port is free)

# Check Docker permissions
docker ps
# Expected: List of containers (empty is OK)
```

### 2. Build Testing

```bash
# Build the image
./scripts/build.sh

# Verify build success
echo $?
# Expected: 0

# Check image exists
docker images prixfixe:latest
# Expected: Image listed with size ~180MB

# Inspect image
docker inspect prixfixe:latest | jq '.[0].Config.Labels'
# Expected: Metadata labels displayed

# Check image layers
docker history prixfixe:latest
# Expected: Multi-stage build layers shown

# Optional: Security scan
docker scout cves prixfixe:latest
# or
trivy image prixfixe:latest
# Expected: No critical vulnerabilities
```

### 3. Container Startup Testing

```bash
# Start container
./scripts/run.sh

# Verify start success
echo $?
# Expected: 0

# Check container is running
docker ps | grep prixfixe-smtp
# Expected: Container listed and status "Up"

# Check health status
docker inspect --format='{{.State.Health.Status}}' prixfixe-smtp
# Expected: "healthy" (after initial startup period)

# Check logs for errors
./scripts/logs.sh --no-follow --tail 50
# Expected: Server startup messages, no errors

# Verify port binding
docker port prixfixe-smtp
# Expected: 2525/tcp -> 0.0.0.0:2525

# Check process running as non-root
docker exec prixfixe-smtp id
# Expected: uid=1000(smtp) gid=1000(smtp)
```

### 4. Basic SMTP Functionality Testing

```bash
# Run automated test
./scripts/test-smtp.sh

# Expected output:
# ✓ Server greeting received
# ✓ EHLO command succeeded
# ✓ MAIL FROM command succeeded
# ✓ RCPT TO command succeeded
# ✓ DATA command succeeded
# ✓ Message accepted
# ✓ Connection closed gracefully

# Manual test with netcat
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

# Expected: Proper SMTP responses (220, 250, 354, 250, 221)
```

### 5. Configuration Testing

```bash
# Test custom domain
docker stop prixfixe-smtp
docker rm prixfixe-smtp
SMTP_DOMAIN=mail.example.com ./scripts/run.sh

# Verify domain in greeting
echo "QUIT" | nc localhost 2525 | head -1
# Expected: 220 mail.example.com ESMTP...

# Test custom port
docker stop prixfixe-smtp
docker rm prixfixe-smtp
SMTP_PORT=8025 ./scripts/run.sh

# Verify port
nc -zv localhost 8025
# Expected: Connection successful

# Test connection limit
docker stop prixfixe-smtp
docker rm prixfixe-smtp
SMTP_MAX_CONNECTIONS=2 ./scripts/run.sh

# Open 3 connections (third should be rejected or queued)
for i in {1..3}; do
  { sleep 10; echo "QUIT"; } | nc localhost 2525 &
done
wait

# Check logs for connection limit handling
./scripts/logs.sh --no-follow --tail 20
```

### 6. Volume Mount Testing

```bash
# Stop container
./scripts/stop.sh

# Create test directory
mkdir -p /tmp/prixfixe-test-mail

# Run with custom volume
docker run -d \
  --name prixfixe-smtp \
  -p 2525:2525 \
  -v /tmp/prixfixe-test-mail:/var/mail \
  prixfixe:latest

# Send test message
./scripts/test-smtp.sh

# Check volume contents
ls -la /tmp/prixfixe-test-mail
# Expected: Files created by smtp user (UID 1000)

# Cleanup
docker stop prixfixe-smtp
docker rm prixfixe-smtp
rm -rf /tmp/prixfixe-test-mail
```

### 7. Resource Limit Testing

```bash
# Run with memory limit
docker run -d \
  --name prixfixe-smtp \
  --memory="512m" \
  -p 2525:2525 \
  prixfixe:latest

# Check memory limit
docker stats prixfixe-smtp --no-stream
# Expected: MEM LIMIT shows 512MiB

# Run with CPU limit
docker stop prixfixe-smtp
docker rm prixfixe-smtp

docker run -d \
  --name prixfixe-smtp \
  --cpus="1.0" \
  -p 2525:2525 \
  prixfixe:latest

# Cleanup
docker stop prixfixe-smtp
docker rm prixfixe-smtp
```

### 8. Restart Policy Testing

```bash
# Run with restart policy
docker run -d \
  --name prixfixe-smtp \
  --restart unless-stopped \
  -p 2525:2525 \
  prixfixe:latest

# Kill the process inside container
docker exec prixfixe-smtp pkill -9 prixfixe-server

# Wait a moment
sleep 5

# Check if container restarted
docker ps | grep prixfixe-smtp
# Expected: Container still running

# Check restart count
docker inspect prixfixe-smtp | jq '.[0].RestartCount'
# Expected: 1 or more

# Cleanup
docker stop prixfixe-smtp
docker rm prixfixe-smtp
```

### 9. Docker Compose Testing

```bash
# Create .env file
cp .env.example .env

# Start with docker-compose
docker-compose up -d

# Verify service is running
docker-compose ps
# Expected: prixfixe service Up

# Test connectivity
./scripts/test-smtp.sh

# View logs
docker-compose logs prixfixe
# Expected: Server startup logs

# Check resource usage
docker-compose stats
# Expected: Resource usage within limits

# Restart service
docker-compose restart prixfixe

# Verify still working
./scripts/test-smtp.sh

# Stop and cleanup
docker-compose down
```

### 10. Helper Script Testing

```bash
# Test build script
./scripts/build.sh
# Expected: Build completes, image created

# Test run script
./scripts/run.sh
# Expected: Container starts successfully

# Test logs script
./scripts/logs.sh --no-follow --tail 10
# Expected: Last 10 log lines shown

# Test stop script
./scripts/stop.sh
# Expected: Container stopped

# Test stop with remove
./scripts/run.sh
./scripts/stop.sh --remove
# Expected: Container stopped and removed

# Test SMTP test script
./scripts/run.sh
sleep 2
./scripts/test-smtp.sh
# Expected: All checks pass
```

### 11. Load Testing (Optional)

```bash
# Install required tools
# apt-get install parallel  # Linux
# brew install parallel      # macOS

# Start server
./scripts/run.sh

# Send 100 concurrent messages
seq 1 100 | parallel -j 10 '
{
  echo "EHLO test.example.com"
  sleep 0.1
  echo "MAIL FROM:<sender{}@example.com>"
  sleep 0.1
  echo "RCPT TO:<recipient@example.com>"
  sleep 0.1
  echo "DATA"
  sleep 0.1
  echo "Subject: Load Test {}"
  echo ""
  echo "Message number {}"
  echo "."
  sleep 0.1
  echo "QUIT"
} | nc localhost 2525
'

# Check logs for errors
./scripts/logs.sh --no-follow | grep -i error
# Expected: No errors (or minimal errors)

# Check resource usage
docker stats prixfixe-smtp --no-stream
```

### 12. Upgrade Testing

```bash
# Tag current image as old
docker tag prixfixe:latest prixfixe:old

# Build new version
./scripts/build.sh

# Stop old container
docker stop prixfixe-smtp
docker rm prixfixe-smtp

# Start new container
./scripts/run.sh

# Verify new version works
./scripts/test-smtp.sh

# Rollback test (if needed)
docker stop prixfixe-smtp
docker rm prixfixe-smtp
docker tag prixfixe:old prixfixe:latest
./scripts/run.sh
```

## Common Issues and Solutions

### Issue: Port Already in Use

**Symptoms**: Container fails to start, "port is already allocated" error

**Solution**:
```bash
# Find what's using the port
lsof -i :2525

# Kill the process or use different port
SMTP_PORT=8025 ./scripts/run.sh
```

### Issue: Permission Denied on Volume

**Symptoms**: Cannot write to mounted volume

**Solution**:
```bash
# Fix permissions
sudo chown -R 1000:1000 ./mail-data

# Or run with different user
docker run --user $(id -u):$(id -g) ...
```

### Issue: Container Exits Immediately

**Symptoms**: Container starts but exits immediately

**Solution**:
```bash
# Check logs
docker logs prixfixe-smtp

# Run in foreground for debugging
docker run --rm -it -p 2525:2525 prixfixe:latest

# Check for missing dependencies
docker run --rm -it prixfixe:latest /bin/bash
ldd /usr/local/bin/prixfixe-server
```

### Issue: Health Check Failing

**Symptoms**: Container shows as unhealthy

**Solution**:
```bash
# Check health check logs
docker inspect prixfixe-smtp | jq '.[0].State.Health'

# Run health check manually
docker exec prixfixe-smtp pgrep -f prixfixe-server

# Adjust health check timing if needed
# (Edit docker-compose.yml or Dockerfile)
```

## Test Results Documentation

After completing tests, document results:

```bash
# Create test report
cat > test-report.md << 'EOF'
# PrixFixe Docker Deployment Test Report

**Date**: $(date)
**Tester**: [Name]
**Environment**: [OS, Docker version]

## Test Results

### Build Phase
- [ ] Pass / [ ] Fail - Build completes
- [ ] Pass / [ ] Fail - Image size reasonable
- [ ] Pass / [ ] Fail - Security scan clean

### Runtime Phase
- [ ] Pass / [ ] Fail - Container starts
- [ ] Pass / [ ] Fail - Health check passes
- [ ] Pass / [ ] Fail - Runs as non-root

### Functionality Phase
- [ ] Pass / [ ] Fail - SMTP commands work
- [ ] Pass / [ ] Fail - Message acceptance
- [ ] Pass / [ ] Fail - Multiple connections

### Configuration Phase
- [ ] Pass / [ ] Fail - Environment variables
- [ ] Pass / [ ] Fail - Volume mounts
- [ ] Pass / [ ] Fail - Resource limits

### Helper Scripts
- [ ] Pass / [ ] Fail - All scripts work

## Issues Found

[List any issues]

## Notes

[Additional observations]
EOF
```

## Automated Testing (Future)

Future versions will include:
- Automated integration test suite
- CI/CD pipeline testing
- Performance benchmarks
- Security scanning automation
- Regression tests

## Support

For testing issues:
- Review [DEPLOYMENT.md](../DEPLOYMENT.md)
- Check Docker logs: `docker logs prixfixe-smtp`
- Verify Docker setup: `docker info`
- Open GitHub issue with test results

---

**Version**: 1.0.0
**Last Updated**: 2025-11-27
