#!/usr/bin/env python3
"""
PrixFixe SMTP Load Generator

A sophisticated load generator for stress testing SMTP servers.
Supports multiple concurrent connections, variable message sizes,
and comprehensive metrics collection.
"""

import asyncio
import time
import json
import random
import sys
from typing import List, Dict, Any
from dataclasses import dataclass, asdict
from datetime import datetime
import click


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
    response_times: List[float] = None

    def __post_init__(self):
        if self.response_times is None:
            self.response_times = []

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

    def to_dict(self) -> Dict[str, Any]:
        """Convert metrics to dictionary for JSON serialization"""
        return {
            'total_messages': self.total_messages,
            'successful_messages': self.successful_messages,
            'failed_messages': self.failed_messages,
            'connection_errors': self.connection_errors,
            'total_bytes_sent': self.total_bytes_sent,
            'duration_seconds': self.duration,
            'messages_per_second': self.messages_per_second,
            'avg_response_time_ms': self.avg_response_time * 1000,
            'min_response_time_ms': self.min_response_time * 1000,
            'max_response_time_ms': self.max_response_time * 1000,
            'start_time': datetime.fromtimestamp(self.start_time).isoformat(),
            'end_time': datetime.fromtimestamp(self.end_time).isoformat() if self.end_time > 0 else None
        }


class SMTPLoadGenerator:
    """Generates SMTP load for stress testing"""

    def __init__(self, servers: List[str], port: int = 2525):
        self.servers = servers
        self.port = port
        self.metrics = TestMetrics()
        self.lock = asyncio.Lock()

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

        except asyncio.TimeoutError:
            async with self.lock:
                self.metrics.connection_errors += 1
            print(f"ERROR: Timeout connecting to {server}")
            return False
        except Exception as e:
            async with self.lock:
                self.metrics.connection_errors += 1
            print(f"ERROR: Exception sending to {server}: {e}")
            return False

    def generate_message_body(self, size_bytes: int) -> str:
        """Generate a message body of approximately the specified size"""
        # Simple fixed message for testing - minimal variability
        message = (
            "From: loadgen@test.local\r\n"
            "To: test@example.com\r\n"
            "Subject: Load Test Message\r\n"
            "\r\n"
            "This is a test message from the load generator.\r\n"
            "It contains multiple lines of text.\r\n"
            "Each line is kept short.\r\n"
        )

        # Pad to desired size if needed
        while len(message) < size_bytes - 50:  # Leave room for safety
            message += "Test line number {}.\r\n".format(len(message))

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

    async def run_burst_test(self, total_messages: int, concurrent_workers: int, message_size: int):
        """Run a burst test with concurrent workers"""
        print(f"Starting burst test: {total_messages} messages, {concurrent_workers} workers")
        print(f"Target servers: {', '.join(self.servers)}")
        print(f"Message size: {message_size} bytes")
        print("-" * 60)

        self.metrics = TestMetrics()
        self.metrics.start_time = time.time()

        messages_per_worker = total_messages // concurrent_workers
        remainder = total_messages % concurrent_workers

        tasks = []
        for i in range(concurrent_workers):
            worker_messages = messages_per_worker + (1 if i < remainder else 0)
            task = asyncio.create_task(self.run_worker(i, worker_messages, message_size))
            tasks.append(task)

        await asyncio.gather(*tasks)

        self.metrics.end_time = time.time()
        return self.metrics

    async def run_sustained_test(self, duration_seconds: int, messages_per_second: int,
                                   message_size: int):
        """Run a sustained load test for a specified duration"""
        print(f"Starting sustained test: {duration_seconds}s duration, {messages_per_second} msg/s")
        print(f"Target servers: {', '.join(self.servers)}")
        print(f"Message size: {message_size} bytes")
        print("-" * 60)

        self.metrics = TestMetrics()
        self.metrics.start_time = time.time()

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
        return self.metrics


def print_metrics(metrics: TestMetrics):
    """Print formatted metrics"""
    print("\n" + "=" * 60)
    print("STRESS TEST RESULTS")
    print("=" * 60)
    print(f"Duration:              {metrics.duration:.2f} seconds")
    print(f"Total Messages:        {metrics.total_messages}")
    print(f"Successful:            {metrics.successful_messages}")
    print(f"Failed:                {metrics.failed_messages}")
    print(f"Connection Errors:     {metrics.connection_errors}")
    print(f"Success Rate:          {(metrics.successful_messages/metrics.total_messages*100) if metrics.total_messages > 0 else 0:.2f}%")
    print(f"Messages/Second:       {metrics.messages_per_second:.2f}")
    print(f"Total Data Sent:       {metrics.total_bytes_sent / 1024 / 1024:.2f} MB")
    print(f"Avg Response Time:     {metrics.avg_response_time * 1000:.2f} ms")
    print(f"Min Response Time:     {metrics.min_response_time * 1000:.2f} ms")
    print(f"Max Response Time:     {metrics.max_response_time * 1000:.2f} ms")
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
def main(servers, port, mode, messages, workers, duration, rate, size, output):
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
            return await generator.run_burst_test(messages, workers, message_size)
        else:
            return await generator.run_sustained_test(duration, rate, message_size)

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
