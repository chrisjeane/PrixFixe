# PrixFixe Deployment Plan

**Created**: 2025-11-27
**Status**: Implementation Phase
**Version**: v0.1.0

## Overview

This document outlines the deployment and configuration strategy for PrixFixe SMTP server, targeting production environments with Docker as the primary deployment method.

## Goals

1. **Easy Deployment**: Simple one-command Docker deployment for end users
2. **Configuration Flexibility**: Environment variables and config files for all settings
3. **Production Ready**: Health checks, logging, security, and monitoring
4. **Multi-Platform Support**: Docker images for both x86_64 and ARM64 (Linux)
5. **Developer Friendly**: Clear documentation and examples

## Deployment Strategies

### 1. Docker Container (Primary)

**Target**: Production servers, cloud platforms, development environments

**Advantages**:
- Consistent environment across platforms
- Easy to deploy and update
- Isolated from host system
- Built-in health checks
- Resource limits

**Components**:
- Multi-stage Dockerfile for minimal image size
- docker-compose.yml for orchestration
- Environment-based configuration
- Volume mounts for persistent data

### 2. Native Binary (Secondary)

**Target**: Direct Linux server deployment, systemd services

**Advantages**:
- Lower overhead
- Direct system integration
- Easier debugging
- Native performance

**Components**:
- Pre-built binaries for Linux
- systemd unit files
- Configuration file support

### 3. Kubernetes (Future)

**Target**: Large-scale deployments, cloud-native environments

**Components** (planned for v0.2.0):
- Kubernetes manifests
- Helm charts
- ConfigMaps and Secrets
- Ingress configuration

## Configuration Strategy

### Environment Variables

All server settings configurable via environment:

```bash
# Server Configuration
SMTP_DOMAIN=mail.example.com
SMTP_PORT=2525
SMTP_MAX_CONNECTIONS=100
SMTP_MAX_MESSAGE_SIZE=10485760

# Logging
SMTP_LOG_LEVEL=info
SMTP_LOG_FORMAT=json

# Storage
SMTP_STORAGE_TYPE=filesystem
SMTP_STORAGE_PATH=/var/mail

# Monitoring
SMTP_METRICS_ENABLED=true
SMTP_METRICS_PORT=9090
```

### Configuration File

YAML-based configuration for complex setups:

```yaml
server:
  domain: mail.example.com
  port: 2525
  maxConnections: 100
  maxMessageSize: 10485760

logging:
  level: info
  format: json
  destination: stdout

storage:
  type: filesystem
  path: /var/mail
  retention: 30d

monitoring:
  enabled: true
  metricsPort: 9090
  healthCheckPort: 8080
```

## Docker Image Strategy

### Multi-Stage Build

1. **Builder Stage**: Swift compilation on Ubuntu 22.04
2. **Runtime Stage**: Minimal Ubuntu base with runtime dependencies only

**Benefits**:
- Small final image size (under 200MB)
- Secure (fewer packages)
- Fast startup

### Image Tags

- `latest`: Latest stable release
- `vX.Y.Z`: Specific version
- `edge`: Latest from main branch
- `develop`: Development builds

### Base Image Selection

**Builder**: `swift:6.0-jammy` (Ubuntu 22.04 + Swift 6.0)
**Runtime**: `ubuntu:22.04` (minimal dependencies)

## Security Considerations

### Container Security

1. **Non-root User**: Run as dedicated `smtp` user (UID 1000)
2. **Read-only Root**: Mount root filesystem as read-only
3. **No Privilege Escalation**: Drop all capabilities
4. **Security Scanning**: Scan images for vulnerabilities
5. **Minimal Attack Surface**: Only necessary packages installed

### Network Security

1. **Port Binding**: Bind only to necessary ports
2. **Host Network Isolation**: Default bridge network
3. **TLS Support**: Ready for STARTTLS (v0.2.0)

### Data Security

1. **Volume Permissions**: Proper ownership and permissions
2. **Secrets Management**: Environment variables or Docker secrets
3. **Log Sanitization**: No sensitive data in logs

## Deployment Architecture

### Single Server Deployment

```
┌─────────────────────────────────────┐
│         Docker Host                  │
│  ┌───────────────────────────────┐  │
│  │   PrixFixe Container          │  │
│  │                               │  │
│  │   Port 2525 (SMTP)            │  │
│  │   Port 9090 (Metrics)         │  │
│  │   Port 8080 (Health)          │  │
│  │                               │  │
│  │   Volume: /var/mail           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### High Availability Deployment (Future)

```
                  ┌─────────────┐
                  │   LB/Proxy  │
                  └──────┬──────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐      ┌────▼────┐     ┌────▼────┐
   │ PrixFixe│      │ PrixFixe│     │ PrixFixe│
   │  Node 1 │      │  Node 2 │     │  Node 3 │
   └────┬────┘      └────┬────┘     └────┬────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                  ┌──────▼──────┐
                  │   Storage   │
                  │  (Shared)   │
                  └─────────────┘
```

## Monitoring and Observability

### Health Checks

1. **Docker Health Check**: Built-in container health monitoring
2. **HTTP Health Endpoint**: `/health` endpoint for load balancers
3. **Startup Probe**: Verify server starts successfully

### Logging

1. **Structured Logging**: JSON format for log aggregation
2. **Log Levels**: DEBUG, INFO, WARN, ERROR
3. **Docker Logs**: Standard output for container logs
4. **Log Rotation**: Handled by Docker logging driver

### Metrics (Future v0.2.0)

1. **Prometheus Metrics**: Expose at `/metrics`
2. **Key Metrics**:
   - Active connections
   - Messages received
   - Message size distribution
   - Error rates
   - Response times

## Resource Requirements

### Minimum (Development)

- CPU: 1 core
- Memory: 512 MB
- Disk: 1 GB
- Network: 10 Mbps

### Recommended (Production)

- CPU: 2-4 cores
- Memory: 2-4 GB
- Disk: 10+ GB (depending on message storage)
- Network: 100 Mbps

### Scaling Guidelines

- **Small**: 1-10 concurrent connections, 100 messages/hour
- **Medium**: 10-100 concurrent connections, 1000 messages/hour
- **Large**: 100-1000 concurrent connections, 10000+ messages/hour

## Backup and Recovery

### Data to Backup

1. **Message Storage**: `/var/mail` directory
2. **Configuration**: Environment variables or config files
3. **Logs**: For audit and troubleshooting

### Backup Strategy

1. **Volume Snapshots**: Docker volumes or host directory
2. **Frequency**: Hourly/Daily based on message volume
3. **Retention**: 7 days minimum, 30 days recommended

### Recovery

1. **Container Recovery**: Restart with same volumes
2. **Data Recovery**: Restore from volume snapshots
3. **Configuration Recovery**: Store in version control

## Deployment Workflow

### Development to Production

1. **Local Development**: Run with docker-compose locally
2. **Testing**: Integration tests in CI/CD
3. **Staging**: Deploy to staging environment
4. **Production**: Deploy with monitoring enabled

### CI/CD Pipeline

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Build  │────▶│   Test   │────▶│  Package │────▶│  Deploy  │
│  (Swift) │     │ (Tests)  │     │ (Docker) │     │ (Prod)   │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

## Platform Support

### Linux (Primary)

- Ubuntu 22.04 LTS or later
- Debian 11 or later
- RHEL 8 or later
- Docker 20.10 or later

### macOS (Development)

- macOS 13.0 (Ventura) or later
- Docker Desktop for Mac
- Development and testing only

## Implementation Phases

### Phase 1: Core Docker Support (Current)

- [x] Multi-stage Dockerfile
- [x] docker-compose.yml
- [x] Environment variable configuration
- [x] Basic health checks
- [x] Deployment documentation
- [x] Helper scripts

### Phase 2: Enhanced Deployment (v0.2.0)

- [ ] Kubernetes manifests
- [ ] Helm charts
- [ ] Metrics and monitoring
- [ ] Log aggregation integration
- [ ] Auto-scaling support
- [ ] TLS/STARTTLS support

### Phase 3: Production Hardening (v0.3.0)

- [ ] Advanced security features
- [ ] Performance tuning
- [ ] Multi-region deployment
- [ ] Disaster recovery procedures
- [ ] Production runbooks

## Success Criteria

1. One-command deployment: `docker-compose up -d`
2. Configuration via environment variables working
3. Health checks operational
4. Logs accessible via `docker logs`
5. Documentation complete and tested
6. Example configurations provided
7. Troubleshooting guide available

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Swift runtime issues in container | High | Low | Test extensively, use stable Swift version |
| Network framework not available | High | Low | Use Foundation sockets on Linux |
| Resource exhaustion | Medium | Medium | Implement resource limits, monitoring |
| Configuration complexity | Low | Medium | Provide sensible defaults, examples |
| Container security vulnerabilities | High | Medium | Regular security scans, minimal base image |

## Support and Documentation

### Documentation to Provide

1. **DEPLOYMENT.md**: Comprehensive deployment guide
2. **docker-compose.example.yml**: Example configurations
3. **env.example**: Environment variable template
4. **config.example.yml**: Configuration file example
5. **TROUBLESHOOTING.md**: Common issues and solutions
6. **SECURITY.md**: Security best practices

### User Support

1. GitHub Issues for bug reports
2. Discussions for questions
3. Examples repository
4. Docker Hub for images

## Timeline

- **Phase 1 Completion**: 2025-11-27 (Today)
- **v0.1.0 Release**: 2025-11-27
- **Docker Hub Publication**: 2025-11-28
- **Phase 2 Start**: 2025-12-15

## Conclusion

This deployment plan focuses on making PrixFixe easy to deploy and operate in production environments while maintaining security and reliability. Docker is the primary deployment method for v0.1.0, with Kubernetes and advanced features planned for future releases.
