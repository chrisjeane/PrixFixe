#!/bin/bash
# PrixFixe SMTP Server - Logs Script
# Views logs from the PrixFixe SMTP server container

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Container ${CONTAINER_NAME} does not exist."
    exit 1
fi

# Default to follow logs
FOLLOW_FLAG="-f"
TAIL_LINES="100"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --no-follow|-n)
            FOLLOW_FLAG=""
            shift
            ;;
        --tail|-t)
            TAIL_LINES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -n, --no-follow    Don't follow log output"
            echo "  -t, --tail N       Number of lines to show from end of logs (default: 100)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info "Viewing logs for ${CONTAINER_NAME}..."
log_info "Press Ctrl+C to exit"
echo ""

docker logs ${FOLLOW_FLAG} --tail "${TAIL_LINES}" "${CONTAINER_NAME}"
