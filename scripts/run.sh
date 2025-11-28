#!/bin/bash
# PrixFixe SMTP Server - Run Script
# Runs the PrixFixe SMTP server in a Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="${IMAGE_NAME:-prixfixe}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-prixfixe-smtp}"

# Default environment variables
SMTP_DOMAIN="${SMTP_DOMAIN:-localhost}"
SMTP_PORT="${SMTP_PORT:-2525}"
SMTP_MAX_CONNECTIONS="${SMTP_MAX_CONNECTIONS:-100}"
SMTP_MAX_MESSAGE_SIZE="${SMTP_MAX_MESSAGE_SIZE:-10485760}"

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

# Check Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if image exists
if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
    log_warn "Image ${IMAGE_NAME}:${IMAGE_TAG} not found."
    log_info "Building image first..."
    "$SCRIPT_DIR/build.sh"
fi

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "Stopping existing container..."
    docker stop "${CONTAINER_NAME}" &> /dev/null || true
    log_info "Removing existing container..."
    docker rm "${CONTAINER_NAME}" &> /dev/null || true
fi

log_info "Starting PrixFixe SMTP Server..."
log_info "Container: ${CONTAINER_NAME}"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Port: ${SMTP_PORT} -> 2525"
log_info "Domain: ${SMTP_DOMAIN}"

# Create mail directory if it doesn't exist
mkdir -p "${PROJECT_DIR}/mail-data"

# Run the container
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${SMTP_PORT}:2525" \
    -e "SMTP_DOMAIN=${SMTP_DOMAIN}" \
    -e "SMTP_PORT=2525" \
    -e "SMTP_MAX_CONNECTIONS=${SMTP_MAX_CONNECTIONS}" \
    -e "SMTP_MAX_MESSAGE_SIZE=${SMTP_MAX_MESSAGE_SIZE}" \
    -v "${PROJECT_DIR}/mail-data:/var/mail" \
    "${IMAGE_NAME}:${IMAGE_TAG}"

if [ $? -eq 0 ]; then
    log_info "Container started successfully!"

    # Wait a moment for the server to start
    sleep 2

    # Check if container is still running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Server is running!"
        log_info ""
        log_info "Connection details:"
        log_info "  Host: localhost"
        log_info "  Port: ${SMTP_PORT}"
        log_info "  Domain: ${SMTP_DOMAIN}"
        log_info ""
        log_info "Useful commands:"
        log_info "  View logs: docker logs -f ${CONTAINER_NAME}"
        log_info "  Stop server: docker stop ${CONTAINER_NAME}"
        log_info "  Test connection: telnet localhost ${SMTP_PORT}"
    else
        log_error "Container failed to start. Check logs with: docker logs ${CONTAINER_NAME}"
        exit 1
    fi
else
    log_error "Failed to start container!"
    exit 1
fi
