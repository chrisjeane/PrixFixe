#!/bin/bash
# PrixFixe SMTP Server - Build Script
# Builds the Docker image for PrixFixe SMTP server

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

# Check Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

log_info "Building PrixFixe SMTP Server Docker image..."
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Project directory: ${PROJECT_DIR}"

cd "$PROJECT_DIR"

# Build the image
log_info "Starting Docker build (this may take several minutes)..."
docker build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file Dockerfile \
    .

if [ $? -eq 0 ]; then
    log_info "Build completed successfully!"
    log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"

    # Show image details
    log_info "Image details:"
    docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    log_info ""
    log_info "Next steps:"
    log_info "  - Run the server: ./scripts/run.sh"
    log_info "  - Deploy with docker-compose: docker-compose up -d"
else
    log_error "Build failed!"
    exit 1
fi
