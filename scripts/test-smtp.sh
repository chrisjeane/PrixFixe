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

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_failure() {
    echo -e "${RED}✗${NC} $1"
}

# Check if netcat is available
if ! command -v nc &> /dev/null; then
    log_error "netcat (nc) is not installed. Please install it first."
    exit 1
fi

log_info "Testing SMTP server at ${SMTP_HOST}:${SMTP_PORT}"
log_info ""

# Function to send SMTP commands and capture output
send_smtp_test() {
    # SMTP requires CRLF line endings per RFC 5321
    # Use printf to ensure proper CRLF (\r\n) line terminators
    printf "EHLO test.example.com\r\n"
    printf "MAIL FROM:<sender@example.com>\r\n"
    printf "RCPT TO:<recipient@example.com>\r\n"
    printf "DATA\r\n"
    printf "From: sender@example.com\r\n"
    printf "To: recipient@example.com\r\n"
    printf "Subject: Test Message from PrixFixe Test Script\r\n"
    printf "\r\n"
    printf "This is a test message sent to verify PrixFixe SMTP server functionality.\r\n"
    printf "Timestamp: $(date)\r\n"
    printf ".\r\n"
    printf "QUIT\r\n"
}

# Run the test
log_test "Connecting to SMTP server and running full SMTP conversation..."
echo ""

result=$(send_smtp_test | nc "${SMTP_HOST}" "${SMTP_PORT}" 2>&1)

# Display the full SMTP conversation
echo "────────────────────────────────────────────────────────────────"
echo "$result"
echo "────────────────────────────────────────────────────────────────"
echo ""

# Initialize test result counters
TESTS_PASSED=0
TESTS_FAILED=0

# Check for successful responses with better patterns
log_info "Validating SMTP responses..."
echo ""

# 1. Server greeting
if echo "$result" | grep -q "220.*ESMTP"; then
    log_success "Server greeting (220 ESMTP)"
    ((TESTS_PASSED++))
else
    log_failure "Server greeting not received"
    ((TESTS_FAILED++))
fi

# 2. EHLO response
if echo "$result" | grep -q "250.*Hello"; then
    log_success "EHLO command accepted (250 Hello)"
    ((TESTS_PASSED++))
else
    log_failure "EHLO command failed"
    ((TESTS_FAILED++))
fi

# 3. MAIL FROM response
if echo "$result" | grep -q "250.*Sender"; then
    log_success "MAIL FROM accepted (250 Sender OK)"
    ((TESTS_PASSED++))
else
    log_failure "MAIL FROM command failed"
    ((TESTS_FAILED++))
fi

# 4. RCPT TO response
if echo "$result" | grep -q "250.*Recipient"; then
    log_success "RCPT TO accepted (250 Recipient OK)"
    ((TESTS_PASSED++))
else
    log_failure "RCPT TO command failed"
    ((TESTS_FAILED++))
fi

# 5. DATA start response
if echo "$result" | grep -q "354.*Start mail input"; then
    log_success "DATA command accepted (354 Start mail input)"
    ((TESTS_PASSED++))
else
    log_failure "DATA command failed"
    ((TESTS_FAILED++))
fi

# 6. Message accepted response
if echo "$result" | grep -q "250.*Message accepted"; then
    log_success "Message accepted (250 Message accepted)"
    ((TESTS_PASSED++))
else
    log_failure "Message not accepted"
    ((TESTS_FAILED++))
fi

# 7. QUIT response
if echo "$result" | grep -q "221.*closing connection"; then
    log_success "Connection closed gracefully (221 Bye)"
    ((TESTS_PASSED++))
else
    log_failure "Connection not closed properly"
    ((TESTS_FAILED++))
fi

# Print summary
echo ""
echo "────────────────────────────────────────────────────────────────"
if [ $TESTS_FAILED -eq 0 ]; then
    log_info "Test Results: ${GREEN}ALL TESTS PASSED${NC} (${TESTS_PASSED}/${TESTS_PASSED})"
    log_info ""
    log_info "PrixFixe SMTP server is functioning correctly!"
    exit 0
else
    log_warn "Test Results: ${TESTS_PASSED} passed, ${RED}${TESTS_FAILED} failed${NC}"
    log_warn ""
    log_warn "Some tests failed. Check the SMTP conversation output above."
    exit 1
fi
