#!/bin/bash
# PrixFixe SMTP Server - SMTP Test Script
# Tests SMTP connectivity and basic functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-2525}"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Check if netcat is available
if ! command -v nc &> /dev/null; then
    log_error "netcat (nc) is not installed. Please install it first."
    exit 1
fi

log_info "Testing SMTP server at ${SMTP_HOST}:${SMTP_PORT}"
log_info ""

# Function to send SMTP commands
send_smtp_test() {
    log_test "Starting SMTP conversation..."

    {
        sleep 1
        echo "EHLO test.example.com"
        sleep 1
        echo "MAIL FROM:<sender@example.com>"
        sleep 1
        echo "RCPT TO:<recipient@example.com>"
        sleep 1
        echo "DATA"
        sleep 1
        echo "From: sender@example.com"
        echo "To: recipient@example.com"
        echo "Subject: Test Message from PrixFixe Test Script"
        echo ""
        echo "This is a test message sent to verify PrixFixe SMTP server functionality."
        echo "."
        sleep 1
        echo "QUIT"
        sleep 1
    } | nc -v "${SMTP_HOST}" "${SMTP_PORT}" 2>&1
}

# Run the test
log_info "Connecting to SMTP server..."
log_info ""

if result=$(send_smtp_test); then
    echo "$result"
    echo ""

    # Check for successful responses
    if echo "$result" | grep -q "220.*ESMTP"; then
        log_info "✓ Server greeting received"
    else
        log_warn "✗ No server greeting detected"
    fi

    if echo "$result" | grep -q "250.*Hello"; then
        log_info "✓ EHLO command succeeded"
    else
        log_warn "✗ EHLO command failed"
    fi

    if echo "$result" | grep -q "250.*Sender.*OK"; then
        log_info "✓ MAIL FROM command succeeded"
    else
        log_warn "✗ MAIL FROM command failed"
    fi

    if echo "$result" | grep -q "250.*Recipient.*OK"; then
        log_info "✓ RCPT TO command succeeded"
    else
        log_warn "✗ RCPT TO command failed"
    fi

    if echo "$result" | grep -q "354.*Start mail input"; then
        log_info "✓ DATA command succeeded"
    else
        log_warn "✗ DATA command failed"
    fi

    if echo "$result" | grep -q "250.*Message accepted"; then
        log_info "✓ Message accepted"
    else
        log_warn "✗ Message not accepted"
    fi

    if echo "$result" | grep -q "221.*closing connection"; then
        log_info "✓ Connection closed gracefully"
    else
        log_warn "✗ Connection not closed properly"
    fi

    echo ""
    log_info "SMTP test completed!"
else
    log_error "Failed to connect to SMTP server"
    log_error "Make sure the server is running and accessible at ${SMTP_HOST}:${SMTP_PORT}"
    exit 1
fi
