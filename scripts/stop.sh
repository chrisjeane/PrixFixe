#!/bin/bash
# PrixFixe SMTP Server - Stop Script
# Stops the PrixFixe SMTP server container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${CONTAINER_NAME:-prixfixe-smtp}"

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

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "Container ${CONTAINER_NAME} does not exist."
    exit 0
fi

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "Stopping container ${CONTAINER_NAME}..."
    docker stop "${CONTAINER_NAME}"
    log_info "Container stopped successfully!"
else
    log_warn "Container ${CONTAINER_NAME} is not running."
fi

# Optionally remove the container
if [ "$1" == "--remove" ] || [ "$1" == "-r" ]; then
    log_info "Removing container ${CONTAINER_NAME}..."
    docker rm "${CONTAINER_NAME}"
    log_info "Container removed successfully!"
fi
