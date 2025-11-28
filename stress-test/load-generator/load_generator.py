#!/usr/bin/env python3
"""
PrixFixe SMTP Load Generator

A sophisticated load generator for stress testing SMTP servers.
Supports multiple concurrent connections, variable message sizes,
comprehensive metrics collection with latency percentiles,
and optional Docker stats monitoring.
"""

import asyncio
import time
import json
import subprocess
import sys
import threading
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
import click


class ErrorType(Enum):
    """Types of errors that can occur during testing"""
    TIMEOUT = "timeout"
    CONNECTION_REFUSED = "connection_refused"
    CONNECTION_RESET = "connection_reset"
    PROTOCOL_ERROR = "protocol_error"
    OTHER = "other"


@dataclass
class TestMetrics:
    """Metrics collected during stress test"""
    total_messages: int = 0
    successful_messages: int = 0
    failed_messages: int = 0
    connection_errors: int = 0
    total_bytes_sent: int = 0
    start_time: float = 0.0
    end_time: float = 0.0
    response_times: List[float] = field(default_factory=list)
    error_breakdown: Dict[str, int] = field(default_factory=dict)
    docker_stats: List[Dict[str, Any]] = field(default_factory=list)

    @property
    def duration(self) -> float:
        return self.end_time - self.start_time if self.end_time > 0 else 0.0

    @property
    def messages_per_second(self) -> float:
        return self.successful_messages / self.duration if self.duration > 0 else 0.0

    @property
    def avg_response_time(self) -> float:
        return sum(self.response_times) / len(self.response_times) if self.response_times else 0.0

    @property
    def min_response_time(self) -> float:
        return min(self.response_times) if self.response_times else 0.0

    @property
    def max_response_time(self) -> float:
        return max(self.response_times) if self.response_times else 0.0

    def percentile(self, p: float) -> float:
        """Calculate the p-th percentile of response times"""
        if not self.response_times:
            return 0.0
        sorted_times = sorted(self.response_times)
        k = (len(sorted_times) - 1) * (p / 100.0)
        f = int(k)
        c = f + 1 if f + 1 < len(sorted_times) else f
        if f == c:
            return sorted_times[int(k)]
        return sorted_times[f] * (c - k) + sorted_times[c] * (k - f)

    @property
    def p50_response_time(self) -> float:
        return self.percentile(50)

    @property
    def p90_response_time(self) -> float:
        return self.percentile(90)

    @property
    def p95_response_time(self) -> float:
        return self.percentile(95)

    @property
    def p99_response_time(self) -> float:
        return self.percentile(99)

    @property
    def p999_response_time(self) -> float:
        return self.percentile(99.9)

    def record_error(self, error_type: ErrorType):
        """Record an error by type"""
        key = error_type.value
        self.error_breakdown[key] = self.error_breakdown.get(key, 0) + 1

    def to_dict(self) -> Dict[str, Any]:
        """Convert metrics to dictionary for JSON serialization"""
        result = {
            'total_messages': self.total_messages,
            'successful_messages': self.successful_messages,
            'failed_messages': self.failed_messages,
            'connection_errors': self.connection_errors,
            'total_bytes_sent': self.total_bytes_sent,
            'duration_seconds': self.duration,
            'messages_per_second': self.messages_per_second,
            'latency_ms': {
                'avg': self.avg_response_time * 1000,
                'min': self.min_response_time * 1000,
                'max': self.max_response_time * 1000,
                'p50': self.p50_response_time * 1000,
                'p90': self.p90_response_time * 1000,
                'p95': self.p95_response_time * 1000,
                'p99': self.p99_response_time * 1000,
                'p99_9': self.p999_response_time * 1000,
            },
            'error_breakdown': self.error_breakdown,
            'start_time': datetime.fromtimestamp(self.start_time).isoformat(),
            'end_time': datetime.fromtimestamp(self.end_time).isoformat() if self.end_time > 0 else None
        }
        if self.docker_stats:
            result['docker_stats'] = {
                'samples': len(self.docker_stats),
                'summary': self._summarize_docker_stats()
            }
        return result

    def _summarize_docker_stats(self) -> Dict[str, Any]:
        """Summarize docker stats across all samples"""
        if not self.docker_stats:
            return {}

        summary = {}
        containers = set()
        for sample in self.docker_stats:
            for container, stats in sample.get('containers', {}).items():
                containers.add(container)

        for container in containers:
            mem_usages = []
            cpu_usages = []
            for sample in self.docker_stats:
                if container in sample.get('containers', {}):
                    stats = sample['containers'][container]
                    if 'mem_usage_mb' in stats:
                        mem_usages.append(stats['mem_usage_mb'])
                    if 'cpu_percent' in stats:
                        cpu_usages.append(stats['cpu_percent'])

            summary[container] = {
                'memory_mb': {
                    'min': min(mem_usages) if mem_usages else 0,
                    'max': max(mem_usages) if mem_usages else 0,
                    'avg': sum(mem_usages) / len(mem_usages) if mem_usages else 0,
                },
                'cpu_percent': {
                    'min': min(cpu_usages) if cpu_usages else 0,
                    'max': max(cpu_usages) if cpu_usages else 0,
                    'avg': sum(cpu_usages) / len(cpu_usages) if cpu_usages else 0,
                }
            }
        return summary


class DockerStatsCollector:
    """Collects Docker stats in background"""

    def __init__(self, container_filter: str = "prixfixe-smtp"):
        self.container_filter = container_filter
        self.stats: List[Dict[str, Any]] = []
        self.running = False
        self.thread: Optional[threading.Thread] = None

    def start(self):
        """Start collecting stats in background"""
        self.running = True
        self.thread = threading.Thread(target=self._collect_loop, daemon=True)
        self.thread.start()

    def stop(self) -> List[Dict[str, Any]]:
        """Stop collecting and return stats"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2.0)
        return self.stats

    def _collect_loop(self):
        """Background collection loop"""
        while self.running:
            try:
                sample = self._collect_sample()
                if sample:
                    self.stats.append(sample)
            except Exception as e:
                pass  # Silently ignore collection errors
            time.sleep(1.0)  # Sample every second

    def _collect_sample(self) -> Optional[Dict[str, Any]]:
        """Collect a single stats sample"""
        try:
            result = subprocess.run(
                ['docker', 'stats', '--no-stream', '--format',
                 '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'],
                capture_output=True, text=True, timeout=5.0
            )
            if result.returncode != 0:
                return None

            sample = {
                'timestamp': time.time(),
                'containers': {}
            }

            for line in result.stdout.strip().split('\n'):
                if not line or self.container_filter not in line:
                    continue
                parts = line.split('\t')
                if len(parts) >= 3:
                    name = parts[0]
                    cpu = parts[1].replace('%', '')
                    mem = parts[2].split('/')[0].strip()

                    # Parse memory (e.g., "50.5MiB" -> 50.5)
                    mem_mb = 0.0
                    if 'GiB' in mem:
                        mem_mb = float(mem.replace('GiB', '')) * 1024
                    elif 'MiB' in mem:
                        mem_mb = float(mem.replace('MiB', ''))
                    elif 'KiB' in mem:
                        mem_mb = float(mem.replace('KiB', '')) / 1024

                    sample['containers'][name] = {
                        'cpu_percent': float(cpu) if cpu else 0.0,
                        'mem_usage_mb': mem_mb
                    }

            return sample if sample['containers'] else None
        except Exception:
            return None


class SMTPLoadGenerator:
    """Generates SMTP load for stress testing"""

    def __init__(self, servers: List[str], port: int = 2525):
        self.servers = servers
        self.port = port
        self.metrics = TestMetrics()
        self.lock = asyncio.Lock()

    def _classify_error(self, error: Exception) -> ErrorType:
        """Classify an exception into an error type"""
        error_str = str(error).lower()
        if isinstance(error, asyncio.TimeoutError):
            return ErrorType.TIMEOUT
        elif 'connection refused' in error_str:
            return ErrorType.CONNECTION_REFUSED
        elif 'connection reset' in error_str or 'errno 104' in error_str:
            return ErrorType.CONNECTION_RESET
        elif any(x in error_str for x in ['500', '501', '503', '550']):
            return ErrorType.PROTOCOL_ERROR
        else:
            return ErrorType.OTHER

    async def send_smtp_message(self, server: str, message_size: int) -> bool:
        """
        Send a single SMTP message using raw socket connection
        Returns True on success, False on failure
        """
        start_time = time.time()

        try:
            # Open TCP connection
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(server, self.port),
                timeout=10.0
            )

            # Read greeting (220)
            greeting = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not greeting.startswith(b'220'):
                print(f"ERROR: Unexpected greeting from {server}: {greeting.decode().strip()}")
                writer.close()
                await writer.wait_closed()
                return False

            # EHLO
            writer.write(b'EHLO loadgen.test\r\n')
            await writer.drain()

            # Read all EHLO responses
            while True:
                line = await asyncio.wait_for(reader.readline(), timeout=5.0)
                if not line.startswith(b'250'):
                    print(f"ERROR: EHLO failed on {server}: {line.decode().strip()}")
                    writer.close()
                    await writer.wait_closed()
                    return False
                if line.startswith(b'250 '):  # Last line starts with "250 " (with space)
                    break

            # MAIL FROM
            writer.write(b'MAIL FROM:<loadgen@test.local>\r\n')
            await writer.drain()
            response = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not response.startswith(b'250'):
                print(f"ERROR: MAIL FROM failed on {server}: {response.decode().strip()}")
                writer.close()
                await writer.wait_closed()
                return False

            # RCPT TO
            writer.write(b'RCPT TO:<test@example.com>\r\n')
            await writer.drain()
            response = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not response.startswith(b'250'):
                print(f"ERROR: RCPT TO failed on {server}: {response.decode().strip()}")
                writer.close()
                await writer.wait_closed()
                return False

            # DATA
            writer.write(b'DATA\r\n')
            await writer.drain()
            response = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not response.startswith(b'354'):
                print(f"ERROR: DATA failed on {server}: {response.decode().strip()}")
                writer.close()
                await writer.wait_closed()
                return False

            # Generate and send message body
            message_body = self.generate_message_body(message_size)

            # Send the message content
            writer.write(message_body.encode('utf-8'))
            await writer.drain()

            # Send terminator
            writer.write(b'.\r\n')
            await writer.drain()

            response = await asyncio.wait_for(reader.readline(), timeout=5.0)
            if not response.startswith(b'250'):
                print(f"ERROR: Message not accepted by {server}: {response.decode().strip()}")
                writer.close()
                await writer.wait_closed()
                return False

            # QUIT
            writer.write(b'QUIT\r\n')
            await writer.drain()
            await asyncio.wait_for(reader.readline(), timeout=5.0)

            writer.close()
            await writer.wait_closed()

            # Record metrics
            response_time = time.time() - start_time
            async with self.lock:
                self.metrics.successful_messages += 1
                self.metrics.total_bytes_sent += len(message_body)
                self.metrics.response_times.append(response_time)

            return True

        except asyncio.TimeoutError as e:
            async with self.lock:
                self.metrics.connection_errors += 1
                self.metrics.record_error(ErrorType.TIMEOUT)
            print(f"ERROR: Timeout connecting to {server}")
            return False
        except Exception as e:
            error_type = self._classify_error(e)
            async with self.lock:
                self.metrics.connection_errors += 1
                self.metrics.record_error(error_type)
            print(f"ERROR: Exception sending to {server}: {e}")
            return False

    def generate_message_body(self, size_bytes: int) -> str:
        """Generate a message body of approximately the specified size

        Note: Lines are kept under 70 characters to stay well within the
        server's 998-byte text line limit per RFC 5321.
        """
        # Simple fixed message for testing - minimal variability
        message = (
            "From: loadgen@test.local\r\n"
            "To: test@example.com\r\n"
            "Subject: Load Test Message\r\n"
            "\r\n"
            "This is a test message from the load generator.\r\n"
            "It contains multiple lines of text.\r\n"
            "Each line is kept short for compatibility.\r\n"
        )

        # Pad to desired size with short lines (under 70 chars each)
        line_num = 0
        while len(message) < size_bytes - 100:  # Leave room for safety
            line_num += 1
            # Keep lines very short - under 50 characters
            message += "Line {} of test message body content.\r\n".format(line_num)

        return message

    async def run_worker(self, worker_id: int, num_messages: int, message_size: int):
        """Worker coroutine that sends messages"""
        for i in range(num_messages):
            # Round-robin server selection
            server = self.servers[i % len(self.servers)]

            async with self.lock:
                self.metrics.total_messages += 1

            success = await self.send_smtp_message(server, message_size)

            if not success:
                async with self.lock:
                    self.metrics.failed_messages += 1

            # Small delay to prevent overwhelming the servers
            await asyncio.sleep(0.01)

    async def run_burst_test(self, total_messages: int, concurrent_workers: int,
                             message_size: int, collect_docker_stats: bool = False):
        """Run a burst test with concurrent workers"""
        print(f"Starting burst test: {total_messages} messages, {concurrent_workers} workers")
        print(f"Target servers: {', '.join(self.servers)}")
        print(f"Message size: {message_size} bytes")
        if collect_docker_stats:
            print("Docker stats collection: ENABLED")
        print("-" * 60)

        self.metrics = TestMetrics()
        self.metrics.start_time = time.time()

        # Start docker stats collection if enabled
        stats_collector = None
        if collect_docker_stats:
            stats_collector = DockerStatsCollector()
            stats_collector.start()

        messages_per_worker = total_messages // concurrent_workers
        remainder = total_messages % concurrent_workers

        tasks = []
        for i in range(concurrent_workers):
            worker_messages = messages_per_worker + (1 if i < remainder else 0)
            task = asyncio.create_task(self.run_worker(i, worker_messages, message_size))
            tasks.append(task)

        await asyncio.gather(*tasks)

        self.metrics.end_time = time.time()

        # Stop docker stats collection
        if stats_collector:
            self.metrics.docker_stats = stats_collector.stop()

        return self.metrics

    async def run_sustained_test(self, duration_seconds: int, messages_per_second: int,
                                 message_size: int, collect_docker_stats: bool = False):
        """Run a sustained load test for a specified duration"""
        print(f"Starting sustained test: {duration_seconds}s duration, {messages_per_second} msg/s")
        print(f"Target servers: {', '.join(self.servers)}")
        print(f"Message size: {message_size} bytes")
        if collect_docker_stats:
            print("Docker stats collection: ENABLED")
        print("-" * 60)

        self.metrics = TestMetrics()
        self.metrics.start_time = time.time()

        # Start docker stats collection if enabled
        stats_collector = None
        if collect_docker_stats:
            stats_collector = DockerStatsCollector()
            stats_collector.start()

        end_time = time.time() + duration_seconds
        interval = 1.0 / messages_per_second

        message_count = 0
        while time.time() < end_time:
            server = self.servers[message_count % len(self.servers)]

            async with self.lock:
                self.metrics.total_messages += 1

            task = asyncio.create_task(self.send_smtp_message(server, message_size))
            message_count += 1

            # Don't wait for completion, just throttle sending rate
            await asyncio.sleep(interval)

        # Wait a bit for remaining messages to complete
        await asyncio.sleep(5)

        self.metrics.end_time = time.time()

        # Stop docker stats collection
        if stats_collector:
            self.metrics.docker_stats = stats_collector.stop()

        return self.metrics


def print_metrics(metrics: TestMetrics):
    """Print formatted metrics with latency percentiles"""
    print("\n" + "=" * 60)
    print("STRESS TEST RESULTS")
    print("=" * 60)
    print(f"Duration:              {metrics.duration:.2f} seconds")
    print(f"Total Messages:        {metrics.total_messages}")
    print(f"Successful:            {metrics.successful_messages}")
    print(f"Failed:                {metrics.failed_messages}")
    print(f"Connection Errors:     {metrics.connection_errors}")
    success_rate = (metrics.successful_messages/metrics.total_messages*100) if metrics.total_messages > 0 else 0
    print(f"Success Rate:          {success_rate:.2f}%")
    print(f"Messages/Second:       {metrics.messages_per_second:.2f}")
    print(f"Total Data Sent:       {metrics.total_bytes_sent / 1024 / 1024:.2f} MB")

    print("\n" + "-" * 60)
    print("LATENCY METRICS")
    print("-" * 60)
    print(f"Min:                   {metrics.min_response_time * 1000:.2f} ms")
    print(f"Avg:                   {metrics.avg_response_time * 1000:.2f} ms")
    print(f"P50 (Median):          {metrics.p50_response_time * 1000:.2f} ms")
    print(f"P90:                   {metrics.p90_response_time * 1000:.2f} ms")
    print(f"P95:                   {metrics.p95_response_time * 1000:.2f} ms")
    print(f"P99:                   {metrics.p99_response_time * 1000:.2f} ms")
    print(f"P99.9:                 {metrics.p999_response_time * 1000:.2f} ms")
    print(f"Max:                   {metrics.max_response_time * 1000:.2f} ms")

    if metrics.error_breakdown:
        print("\n" + "-" * 60)
        print("ERROR BREAKDOWN")
        print("-" * 60)
        for error_type, count in sorted(metrics.error_breakdown.items()):
            print(f"{error_type:20}   {count}")

    if metrics.docker_stats:
        print("\n" + "-" * 60)
        print("RESOURCE USAGE (Docker Stats)")
        print("-" * 60)
        summary = metrics._summarize_docker_stats()
        for container, stats in sorted(summary.items()):
            print(f"\n{container}:")
            mem = stats.get('memory_mb', {})
            cpu = stats.get('cpu_percent', {})
            print(f"  Memory: {mem.get('avg', 0):.1f} MB avg, {mem.get('max', 0):.1f} MB max")
            print(f"  CPU:    {cpu.get('avg', 0):.1f}% avg, {cpu.get('max', 0):.1f}% max")

    print("=" * 60)


@click.command()
@click.option('--servers', '-s', required=True, help='Comma-separated list of server hostnames')
@click.option('--port', '-p', default=2525, help='SMTP port (default: 2525)')
@click.option('--mode', '-m', type=click.Choice(['burst', 'sustained']), required=True,
              help='Test mode: burst or sustained')
@click.option('--messages', '-n', type=int, default=1000, help='Total messages to send (burst mode)')
@click.option('--workers', '-w', type=int, default=10, help='Concurrent workers (burst mode)')
@click.option('--duration', '-d', type=int, default=60, help='Test duration in seconds (sustained mode)')
@click.option('--rate', '-r', type=int, default=10, help='Messages per second (sustained mode)')
@click.option('--size', type=click.Choice(['small', 'medium', 'large', 'xlarge']), default='medium',
              help='Message size: small(1KB), medium(10KB), large(100KB), xlarge(1MB)')
@click.option('--output', '-o', help='Output file for JSON results')
@click.option('--docker-stats', is_flag=True, help='Collect Docker container stats during test')
def main(servers, port, mode, messages, workers, duration, rate, size, output, docker_stats):
    """PrixFixe SMTP Load Generator - Stress test SMTP servers"""

    # Parse servers
    server_list = [s.strip() for s in servers.split(',')]

    # Determine message size
    size_map = {
        'small': 1024,          # 1 KB
        'medium': 10240,        # 10 KB
        'large': 102400,        # 100 KB
        'xlarge': 1048576       # 1 MB
    }
    message_size = size_map[size]

    # Create load generator
    generator = SMTPLoadGenerator(server_list, port)

    # Run test
    async def run_test():
        if mode == 'burst':
            return await generator.run_burst_test(messages, workers, message_size, docker_stats)
        else:
            return await generator.run_sustained_test(duration, rate, message_size, docker_stats)

    try:
        metrics = asyncio.run(run_test())
        print_metrics(metrics)

        # Save results if output file specified
        if output:
            results = {
                'test_type': mode,
                'servers': server_list,
                'port': port,
                'message_size': message_size,
                'concurrent_workers': workers if mode == 'burst' else None,
                'target_rate': rate if mode == 'sustained' else None,
                'metrics': metrics.to_dict()
            }

            with open(output, 'w') as f:
                json.dump(results, f, indent=2)

            print(f"\nResults saved to: {output}")

        # Exit with appropriate code
        sys.exit(0 if metrics.failed_messages == 0 else 1)

    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n\nFATAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
