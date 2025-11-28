# PrixFixe SMTP Server - Stress Testing Guide

This guide covers the comprehensive stress testing infrastructure for PrixFixe SMTP servers, including multi-server deployment, load generation, and results analysis.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Test Scenarios](#test-scenarios)
6. [Configuration](#configuration)
7. [Running Tests](#running-tests)
8. [Analyzing Results](#analyzing-results)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Usage](#advanced-usage)

---

## Overview

The PrixFixe stress test infrastructure provides:

- **Multiple SMTP Servers**: Deploy 5 independent SMTP server instances
- **Load Generator**: Python-based async load generator with full SMTP protocol support
- **Traffic Patterns**: Burst and sustained load scenarios
- **Message Sizes**: Variable message sizes from 1KB to 1MB
- **Metrics Collection**: Comprehensive performance and reliability metrics
- **Results Analysis**: Automated analysis and reporting tools

### Key Features

- Round-robin load distribution across servers
- Concurrent connection handling (configurable workers)
- Real-time metrics collection
- Docker-based isolated testing environment
- Resource usage monitoring
- Detailed logging and result archiving

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Stress Test Network                       │
│                    (172.25.0.0/16)                           │
│                                                               │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│  │   SMTP-1    │     │   SMTP-2    │     │   SMTP-3    │   │
│  │ 172.25.0.11 │     │ 172.25.0.12 │     │ 172.25.0.13 │   │
│  │   :2525     │     │   :2525     │     │   :2525     │   │
│  └─────────────┘     └─────────────┘     └─────────────┘   │
│                                                               │
│  ┌─────────────┐     ┌─────────────┐                        │
│  │   SMTP-4    │     │   SMTP-5    │                        │
│  │ 172.25.0.14 │     │ 172.25.0.15 │                        │
│  │   :2525     │     │   :2525     │                        │
│  └─────────────┘     └─────────────┘                        │
│                                                               │
│  ┌──────────────────────────────────────────────────┐       │
│  │           Load Generator                          │       │
│  │  - Async Python SMTP client                      │       │
│  │  - Configurable workers & message sizes          │       │
│  │  - Round-robin server selection                  │       │
│  │  - Metrics collection & reporting                │       │
│  └──────────────────────────────────────────────────┘       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │
         ├─→ Results exported to ./stress-test/results/
         └─→ Logs exported to ./stress-test/results/server*-logs/
```

### Resource Limits

Each SMTP server is configured with:

- **CPU**: 0.5-2.0 cores
- **Memory**: 512MB-2GB
- **Connections**: 100 concurrent max
- **Message Size**: 10MB max

---

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later (or docker-compose v1.29+)
- **Bash**: Version 4.0 or later
- **jq**: (Optional) For JSON result analysis

### System Requirements

- **CPU**: 4+ cores recommended
- **Memory**: 8GB+ recommended
- **Disk**: 5GB+ free space for logs and results
- **Network**: Docker bridge networking support

### Installation Verification

```bash
# Check Docker
docker --version
docker compose version

# Check available resources
docker system info | grep -E "CPUs|Total Memory"

# Verify network capability
docker network ls
```

---

## Quick Start

### 1. Build Images

Build both the SMTP server and load generator images:

```bash
./scripts/stress-test.sh build
```

This will:
- Build the PrixFixe SMTP server image
- Build the load generator image
- Tag images appropriately

### 2. Run Quick Test

Run a quick smoke test to verify everything works:

```bash
./scripts/stress-test.sh test-quick
```

This sends 100 small messages across all 5 servers and reports results.

### 3. View Results

```bash
./scripts/analyze-results.sh latest
```

---

## Test Scenarios

The stress test infrastructure includes several pre-configured test scenarios:

### Quick Smoke Test

**Purpose**: Verify basic functionality

```bash
./scripts/stress-test.sh test-quick
```

- **Messages**: 100
- **Workers**: 10
- **Message Size**: 1KB (small)
- **Duration**: ~10 seconds

### Burst Load Test

**Purpose**: Test high-volume burst traffic

```bash
./scripts/stress-test.sh test-burst
```

- **Messages**: 5,000
- **Workers**: 50 concurrent
- **Message Size**: 10KB (medium)
- **Duration**: ~60-90 seconds

### Sustained Load Test

**Purpose**: Test constant load over time

```bash
./scripts/stress-test.sh test-sustained
```

- **Duration**: 60 seconds
- **Rate**: 50 messages/second
- **Message Size**: 10KB (medium)
- **Total Messages**: ~3,000

### Heavy Load Test

**Purpose**: Maximum stress testing

```bash
./scripts/stress-test.sh test-heavy
```

- **Messages**: 10,000
- **Workers**: 100 concurrent
- **Message Size**: 10KB (medium)
- **Duration**: ~120-180 seconds

### Mixed Message Sizes

**Purpose**: Test with varying message sizes

```bash
./scripts/stress-test.sh test-mixed
```

Runs sequential tests with:
- 1,000 small messages (1KB)
- 1,000 medium messages (10KB)
- 500 large messages (100KB)
- 100 extra-large messages (1MB)

### Comprehensive Test Suite

**Purpose**: Run all test scenarios

```bash
./scripts/stress-test.sh test-all
```

Executes all test scenarios in sequence with cooldown periods.

---

## Configuration

### Message Sizes

The load generator supports four message size categories:

| Size    | Bytes    | Typical Use Case |
|---------|----------|------------------|
| small   | 1 KB     | Simple notifications |
| medium  | 10 KB    | Standard emails |
| large   | 100 KB   | Emails with attachments |
| xlarge  | 1 MB     | Large attachments |

### Test Modes

#### Burst Mode

Sends a fixed number of messages as fast as possible using concurrent workers.

```bash
--mode burst --messages 5000 --workers 50 --size medium
```

**Parameters**:
- `--messages`: Total messages to send
- `--workers`: Number of concurrent workers
- `--size`: Message size category

#### Sustained Mode

Sends messages at a constant rate for a specified duration.

```bash
--mode sustained --duration 60 --rate 50 --size medium
```

**Parameters**:
- `--duration`: Test duration in seconds
- `--rate`: Messages per second
- `--size`: Message size category

### Custom Configuration

#### Modify Server Count

Edit `docker-compose.stress-test.yml`:

```yaml
# Add/remove server instances
smtp-server-6:
  # ... copy configuration from smtp-server-5 and adjust IP
```

Update the load generator command to include new servers:

```yaml
command:
  - "--servers"
  - "smtp-server-1,smtp-server-2,...,smtp-server-6"
```

#### Adjust Resource Limits

Edit resource limits in `docker-compose.stress-test.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'        # Increase CPU limit
      memory: 4G         # Increase memory limit
```

#### Modify SMTP Configuration

Set environment variables for each server:

```yaml
environment:
  SMTP_MAX_CONNECTIONS: 200      # Increase max connections
  SMTP_MAX_MESSAGE_SIZE: 52428800  # 50 MB
```

---

## Running Tests

### Using the Stress Test Script

The main stress test script (`scripts/stress-test.sh`) provides a complete workflow:

#### Available Commands

```bash
# Build images
./scripts/stress-test.sh build

# Start servers only (for manual testing)
./scripts/stress-test.sh start

# Stop all containers
./scripts/stress-test.sh stop

# Clean up (stops containers, optionally removes volumes)
./scripts/stress-test.sh clean

# Show server status and resource usage
./scripts/stress-test.sh status

# Collect and archive logs
./scripts/stress-test.sh logs

# Run pre-defined test scenarios
./scripts/stress-test.sh test-quick
./scripts/stress-test.sh test-burst
./scripts/stress-test.sh test-sustained
./scripts/stress-test.sh test-heavy
./scripts/stress-test.sh test-mixed
./scripts/stress-test.sh test-all

# Run custom test
./scripts/stress-test.sh run-custom --mode burst --messages 2000 --workers 30 --size large
```

### Using Docker Compose Directly

For more control, use docker-compose commands directly:

#### Start Servers

```bash
docker-compose -f docker-compose.stress-test.yml up -d \
  smtp-server-1 smtp-server-2 smtp-server-3 smtp-server-4 smtp-server-5
```

#### Wait for Health Checks

```bash
# Check status
docker-compose -f docker-compose.stress-test.yml ps

# Wait until all show "healthy"
```

#### Run Load Generator

```bash
docker-compose -f docker-compose.stress-test.yml run --rm load-generator \
  --servers "smtp-server-1,smtp-server-2,smtp-server-3,smtp-server-4,smtp-server-5" \
  --port 2525 \
  --mode burst \
  --messages 1000 \
  --workers 20 \
  --size medium \
  --output /results/my-test.json
```

#### Monitor Resources

```bash
# View logs
docker-compose -f docker-compose.stress-test.yml logs -f smtp-server-1

# Monitor resource usage
docker stats prixfixe-smtp-1 prixfixe-smtp-2 prixfixe-smtp-3 prixfixe-smtp-4 prixfixe-smtp-5

# Check health
docker inspect prixfixe-smtp-1 | grep -A 10 Health
```

#### Stop and Clean Up

```bash
# Stop all
docker-compose -f docker-compose.stress-test.yml down

# Remove volumes
docker-compose -f docker-compose.stress-test.yml down -v
```

---

## Analyzing Results

### Automated Analysis

Use the analysis script to examine results:

```bash
# List all result files
./scripts/analyze-results.sh list

# Analyze most recent test
./scripts/analyze-results.sh latest

# Analyze specific test
./scripts/analyze-results.sh analyze stress-test/results/20241127-120000-burst.json

# Generate summary of all tests
./scripts/analyze-results.sh summary

# Compare two tests
./scripts/analyze-results.sh compare file1.json file2.json
```

### Result Metrics

Each test result includes:

#### Message Statistics
- Total messages sent
- Successful deliveries
- Failed deliveries
- Connection errors
- Success rate percentage

#### Performance Metrics
- Test duration (seconds)
- Messages per second (throughput)
- Total data transferred (MB)

#### Response Time Statistics
- Average response time (ms)
- Minimum response time (ms)
- Maximum response time (ms)

### Sample Output

```
============================================================================
Analysis: 20241127-120000-burst.json
============================================================================

Test Type:         burst
Servers:           smtp-server-1, smtp-server-2, smtp-server-3, smtp-server-4, smtp-server-5
Message Size:      10 KB

Messages:
  Total:           5000
  Successful:      4998
  Failed:          2
  Conn Errors:     0
  Success Rate:    99.96%

Performance:
  Duration:        87.34s
  Messages/Sec:    57.23
  Total Data:      48.82 MB

Response Times:
  Average:         152.34 ms
  Minimum:         45.12 ms
  Maximum:         1203.45 ms

[SUCCESS] Status: PASSED - No errors
```

### Result Files

Results are saved in `stress-test/results/` with timestamps:

```
stress-test/results/
├── 20241127-120000-burst.json
├── 20241127-120500-sustained.json
├── 20241127-121000-heavy.json
├── 20241127-120000-logs.tar.gz
└── server1-logs/
    └── ...
```

### Manual Analysis

Result files are JSON formatted for easy parsing:

```bash
# Extract specific metrics
cat stress-test/results/test.json | jq '.metrics.messages_per_second'

# Get success rate
cat stress-test/results/test.json | jq '.metrics.successful_messages / .metrics.total_messages'
```

---

## Known Issues

### 512-Byte Line Limit in DATA Mode

**Status**: Known Bug in PrixFixe v0.1.0

The PrixFixe SMTP server currently enforces a 512-byte line length limit even during DATA mode (message content). This is stricter than RFC 5321 which allows up to 998 bytes for message content lines. This affects the load generator when sending messages with long lines.

**Impact**: Load tests may fail with "500 Command too long" errors if message content contains lines longer than 512 bytes.

**Workaround**: The load generator has been configured to generate messages with very short lines (under 80 characters) to work within this limitation.

**Resolution**: This will be fixed in a future version of PrixFixe by implementing separate line length limits for SMTP commands vs. DATA content.

---

## Troubleshooting

### Common Issues

#### Servers Won't Start

**Symptom**: Containers exit immediately or fail health checks

**Solutions**:

1. Check Docker resources:
   ```bash
   docker system info
   ```

2. View server logs:
   ```bash
   docker-compose -f docker-compose.stress-test.yml logs smtp-server-1
   ```

3. Verify image builds:
   ```bash
   docker images | grep prixfixe
   ```

4. Test single server:
   ```bash
   docker run --rm -p 2525:2525 prixfixe-smtp:latest
   ```

#### Connection Errors During Testing

**Symptom**: High connection error count in results

**Solutions**:

1. Verify servers are healthy:
   ```bash
   docker-compose -f docker-compose.stress-test.yml ps
   ```

2. Check network connectivity:
   ```bash
   docker exec prixfixe-loadgen ping smtp-server-1
   ```

3. Reduce concurrent workers:
   ```bash
   --workers 10  # Instead of 100
   ```

4. Check server resource limits:
   ```bash
   docker stats prixfixe-smtp-1
   ```

#### Poor Performance / Low Throughput

**Symptom**: Messages per second lower than expected

**Solutions**:

1. Increase server resources in `docker-compose.stress-test.yml`:
   ```yaml
   limits:
     cpus: '4.0'
     memory: 4G
   ```

2. Check host system load:
   ```bash
   top
   docker stats
   ```

3. Reduce message size or concurrent workers

4. Monitor Docker daemon:
   ```bash
   docker system events
   ```

#### Out of Memory Errors

**Symptom**: Containers killed due to OOM

**Solutions**:

1. Increase memory limits in docker-compose.stress-test.yml
2. Reduce `SMTP_MAX_CONNECTIONS` environment variable
3. Reduce concurrent workers in load tests
4. Check host available memory

#### Results Not Saved

**Symptom**: No JSON files in results directory

**Solutions**:

1. Verify results directory exists:
   ```bash
   ls -la stress-test/results/
   ```

2. Check volume mounts:
   ```bash
   docker inspect prixfixe-loadgen | grep -A 5 Mounts
   ```

3. Ensure `--output` parameter is provided:
   ```bash
   --output /results/test.json
   ```

4. Check file permissions:
   ```bash
   ls -la stress-test/results/
   chmod -R 755 stress-test/results/
   ```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Set bash debug mode
bash -x ./scripts/stress-test.sh test-quick

# View load generator output
docker-compose -f docker-compose.stress-test.yml run --rm load-generator \
  --servers "smtp-server-1" \
  --mode burst \
  --messages 10 \
  --workers 1 \
  --size small
```

---

## Advanced Usage

### Custom Load Patterns

#### Ramp-Up Test

Gradually increase load:

```bash
# Start with low load
./scripts/stress-test.sh run-custom --mode sustained --duration 30 --rate 10 --size small
sleep 10

# Increase load
./scripts/stress-test.sh run-custom --mode sustained --duration 30 --rate 25 --size small
sleep 10

# Maximum load
./scripts/stress-test.sh run-custom --mode sustained --duration 30 --rate 50 --size small
```

#### Spike Test

Test sudden traffic spikes:

```bash
# Normal load
./scripts/stress-test.sh run-custom --mode sustained --duration 60 --rate 20 --size medium &
NORMAL_PID=$!

# Wait 30s then spike
sleep 30
./scripts/stress-test.sh run-custom --mode burst --messages 1000 --workers 50 --size medium

# Wait for normal load to finish
wait $NORMAL_PID
```

### Integration with CI/CD

#### Example GitHub Actions Workflow

```yaml
name: SMTP Stress Test

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  stress-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Run stress tests
        run: |
          ./scripts/stress-test.sh test-quick
          ./scripts/stress-test.sh test-burst

      - name: Analyze results
        run: |
          ./scripts/analyze-results.sh summary

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: stress-test-results
          path: stress-test/results/*.json
```

### Performance Benchmarking

Create baseline performance metrics:

```bash
# Run standardized benchmark
./scripts/stress-test.sh run-custom \
  --mode burst \
  --messages 10000 \
  --workers 50 \
  --size medium \
  --output /results/benchmark-baseline.json

# After code changes, run again
./scripts/stress-test.sh run-custom \
  --mode burst \
  --messages 10000 \
  --workers 50 \
  --size medium \
  --output /results/benchmark-new.json

# Compare results
./scripts/analyze-results.sh compare \
  stress-test/results/benchmark-baseline.json \
  stress-test/results/benchmark-new.json
```

### Scaling Tests

Test with different server counts:

```bash
# Test with 3 servers
docker-compose -f docker-compose.stress-test.yml up -d \
  smtp-server-1 smtp-server-2 smtp-server-3

docker-compose -f docker-compose.stress-test.yml run --rm load-generator \
  --servers "smtp-server-1,smtp-server-2,smtp-server-3" \
  --mode burst --messages 5000 --workers 50 --size medium \
  --output /results/scale-3servers.json

# Stop servers
docker-compose -f docker-compose.stress-test.yml down

# Test with 5 servers
./scripts/stress-test.sh test-burst
```

### Custom Metrics Collection

Extend the load generator to collect custom metrics:

```python
# In load_generator.py, add custom metrics
@dataclass
class TestMetrics:
    # ... existing metrics ...
    custom_metric: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        result = {
            # ... existing fields ...
            'custom_metric': self.custom_metric
        }
        return result
```

---

## Best Practices

### Testing Strategy

1. **Start Small**: Begin with quick tests to verify setup
2. **Incremental Load**: Gradually increase load to find limits
3. **Monitor Resources**: Watch CPU, memory, and network usage
4. **Baseline First**: Establish baseline performance before changes
5. **Consistent Environment**: Use same configuration for comparable tests

### Resource Management

1. **Clean Up**: Always run cleanup after tests
2. **Log Rotation**: Archive old logs regularly
3. **Volume Management**: Remove old volumes periodically
4. **Image Pruning**: Clean unused Docker images

### Result Analysis

1. **Save All Results**: Keep historical data for trend analysis
2. **Document Changes**: Note configuration changes between tests
3. **Compare Trends**: Look for performance degradation over time
4. **Set Thresholds**: Define acceptable performance ranges

---

## Support and Contributing

### Getting Help

- Check logs: `./scripts/stress-test.sh logs`
- View status: `./scripts/stress-test.sh status`
- Review results: `./scripts/analyze-results.sh summary`

### Reporting Issues

When reporting issues, include:

1. Output from `./scripts/stress-test.sh status`
2. Relevant log files from `stress-test/results/`
3. Test configuration used
4. System specifications (CPU, RAM, Docker version)

---

## Appendix

### File Structure

```
PrixFixe/
├── docker-compose.stress-test.yml    # Multi-server stress test config
├── scripts/
│   ├── stress-test.sh                # Main test runner
│   └── analyze-results.sh            # Results analysis
└── stress-test/
    ├── load-generator/
    │   ├── Dockerfile                # Load generator image
    │   ├── load_generator.py         # Python load generator
    │   └── entrypoint.sh             # Container entrypoint
    ├── config/                       # Test configurations
    └── results/                      # Test results and logs
        ├── *.json                    # Test results
        ├── *-logs.tar.gz             # Archived logs
        └── server*-logs/             # Individual server logs
```

### Environment Variables

Available environment variables for SMTP servers:

| Variable | Default | Description |
|----------|---------|-------------|
| SMTP_DOMAIN | localhost | Server domain name |
| SMTP_PORT | 2525 | SMTP listening port |
| SMTP_MAX_CONNECTIONS | 100 | Maximum concurrent connections |
| SMTP_MAX_MESSAGE_SIZE | 10485760 | Maximum message size (bytes) |

### Network Configuration

Stress test network details:

- **Network**: `stress-test-net`
- **Driver**: bridge
- **Subnet**: 172.25.0.0/16
- **Gateway**: 172.25.0.1
- **Server IPs**: 172.25.0.11 - 172.25.0.15

---

## Version History

- **v1.0.0** (2024-11-27): Initial stress test infrastructure
  - 5-server deployment
  - Python async load generator
  - Burst and sustained test modes
  - Automated analysis tools

---

For more information, see the main [DEPLOYMENT.md](../DEPLOYMENT.md) guide.
