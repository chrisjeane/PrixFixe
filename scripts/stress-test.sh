#!/bin/bash
# PrixFixe SMTP Stress Test Runner
# Comprehensive stress testing infrastructure for multiple SMTP servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.stress-test.yml"
RESULTS_DIR="stress-test/results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print header
print_header() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"

    # Create results directory
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR/server1-logs"
    mkdir -p "$RESULTS_DIR/server2-logs"
    mkdir -p "$RESULTS_DIR/server3-logs"
    mkdir -p "$RESULTS_DIR/server4-logs"
    mkdir -p "$RESULTS_DIR/server5-logs"
    print_success "Results directory created"
}

# Function to build images
build_images() {
    print_header "Building Docker Images"

    print_info "Building SMTP server image..."
    docker build -t prixfixe-smtp:latest -f Dockerfile .

    print_info "Building load generator image..."
    docker build -t prixfixe-loadgen:latest -f stress-test/load-generator/Dockerfile stress-test/load-generator/

    print_success "Images built successfully"
}

# Function to start servers
start_servers() {
    print_header "Starting SMTP Servers"

    print_info "Starting 5 SMTP server instances..."
    docker-compose -f "$COMPOSE_FILE" up -d \
        smtp-server-1 \
        smtp-server-2 \
        smtp-server-3 \
        smtp-server-4 \
        smtp-server-5

    print_info "Waiting for servers to be healthy..."
    local max_wait=60
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local healthy_count=$(docker-compose -f "$COMPOSE_FILE" ps | grep "healthy" | wc -l | tr -d ' ')
        if [ "$healthy_count" -eq "5" ]; then
            print_success "All 5 servers are healthy"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done

    echo ""
    print_error "Servers failed to become healthy within ${max_wait}s"
    docker-compose -f "$COMPOSE_FILE" ps
    return 1
}

# Function to run a test scenario
run_test() {
    local test_name=$1
    shift
    local test_args=("$@")

    print_header "Running Test: $test_name"

    local output_file="$RESULTS_DIR/${TIMESTAMP}-${test_name}.json"

    print_info "Test configuration:"
    for arg in "${test_args[@]}"; do
        echo "  $arg"
    done
    echo ""

    # Run the load generator
    docker-compose -f "$COMPOSE_FILE" run --rm load-generator \
        --servers "smtp-server-1,smtp-server-2,smtp-server-3,smtp-server-4,smtp-server-5" \
        --port 2525 \
        --output "/results/${TIMESTAMP}-${test_name}.json" \
        "${test_args[@]}"

    if [ $? -eq 0 ]; then
        print_success "Test completed successfully"
        if [ -f "$output_file" ]; then
            print_info "Results saved to: $output_file"
        fi
        return 0
    else
        print_warning "Test completed with errors"
        return 1
    fi
}

# Function to monitor servers
monitor_servers() {
    print_header "Server Status"

    docker-compose -f "$COMPOSE_FILE" ps

    echo ""
    print_info "Resource usage:"
    docker stats --no-stream \
        prixfixe-smtp-1 \
        prixfixe-smtp-2 \
        prixfixe-smtp-3 \
        prixfixe-smtp-4 \
        prixfixe-smtp-5 2>/dev/null || true
}

# Function to collect logs
collect_logs() {
    print_header "Collecting Logs"

    local log_archive="$RESULTS_DIR/${TIMESTAMP}-logs.tar.gz"

    print_info "Collecting container logs..."
    for i in 1 2 3 4 5; do
        docker-compose -f "$COMPOSE_FILE" logs "smtp-server-${i}" > "$RESULTS_DIR/server${i}-container.log" 2>&1 || true
    done

    print_info "Creating log archive..."
    tar -czf "$log_archive" -C "$RESULTS_DIR" \
        server1-logs server2-logs server3-logs server4-logs server5-logs \
        server1-container.log server2-container.log server3-container.log \
        server4-container.log server5-container.log 2>/dev/null || true

    if [ -f "$log_archive" ]; then
        print_success "Logs archived to: $log_archive"
    fi
}

# Function to stop and cleanup
cleanup() {
    print_header "Cleanup"

    print_info "Stopping all containers..."
    docker-compose -f "$COMPOSE_FILE" down

    print_info "Removing volumes (optional)..."
    read -p "Do you want to remove data volumes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f "$COMPOSE_FILE" down -v
        print_success "Volumes removed"
    else
        print_info "Volumes preserved"
    fi
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    build               Build Docker images
    start               Start SMTP servers
    stop                Stop all containers
    clean               Stop containers and clean up
    status              Show server status and resource usage
    logs                Collect and archive logs

    test-quick          Run quick smoke test (100 messages)
    test-burst          Run burst test (5000 messages, 50 workers)
    test-sustained      Run sustained test (60s, 50 msg/s)
    test-heavy          Run heavy load test (10000 messages, 100 workers)
    test-mixed          Run mixed message size tests
    test-all            Run all test scenarios

    run-custom          Run custom test with manual parameters

Examples:
    $0 build            # Build all images
    $0 start            # Start servers
    $0 test-quick       # Run quick test
    $0 test-all         # Run all tests
    $0 clean            # Clean up everything

EOF
}

# Main execution
main() {
    local command=${1:-help}

    case "$command" in
        build)
            check_prerequisites
            build_images
            ;;

        start)
            check_prerequisites
            start_servers
            monitor_servers
            ;;

        stop)
            print_info "Stopping containers..."
            docker-compose -f "$COMPOSE_FILE" down
            print_success "Containers stopped"
            ;;

        clean)
            cleanup
            ;;

        status)
            monitor_servers
            ;;

        logs)
            collect_logs
            ;;

        test-quick)
            check_prerequisites
            build_images
            start_servers
            run_test "quick" --mode burst --messages 100 --workers 10 --size small
            monitor_servers
            collect_logs
            ;;

        test-burst)
            check_prerequisites
            build_images
            start_servers
            run_test "burst" --mode burst --messages 5000 --workers 50 --size medium
            monitor_servers
            collect_logs
            ;;

        test-sustained)
            check_prerequisites
            build_images
            start_servers
            run_test "sustained" --mode sustained --duration 60 --rate 50 --size medium
            monitor_servers
            collect_logs
            ;;

        test-heavy)
            check_prerequisites
            build_images
            start_servers
            run_test "heavy" --mode burst --messages 10000 --workers 100 --size medium
            monitor_servers
            collect_logs
            ;;

        test-mixed)
            check_prerequisites
            build_images
            start_servers

            print_header "Mixed Message Size Test Suite"

            run_test "small-messages" --mode burst --messages 1000 --workers 20 --size small
            sleep 5

            run_test "medium-messages" --mode burst --messages 1000 --workers 20 --size medium
            sleep 5

            run_test "large-messages" --mode burst --messages 500 --workers 10 --size large
            sleep 5

            run_test "xlarge-messages" --mode burst --messages 100 --workers 5 --size xlarge

            monitor_servers
            collect_logs
            ;;

        test-all)
            check_prerequisites
            build_images
            start_servers

            print_header "Comprehensive Test Suite"

            # Quick smoke test
            run_test "01-smoke" --mode burst --messages 100 --workers 10 --size small
            sleep 5

            # Burst tests
            run_test "02-burst-small" --mode burst --messages 2000 --workers 40 --size small
            sleep 5

            run_test "03-burst-medium" --mode burst --messages 2000 --workers 40 --size medium
            sleep 5

            run_test "04-burst-large" --mode burst --messages 1000 --workers 20 --size large
            sleep 10

            # Sustained tests
            run_test "05-sustained-low" --mode sustained --duration 30 --rate 20 --size medium
            sleep 5

            run_test "06-sustained-high" --mode sustained --duration 60 --rate 50 --size medium
            sleep 10

            # Heavy load
            run_test "07-heavy-load" --mode burst --messages 10000 --workers 100 --size medium

            monitor_servers
            collect_logs

            print_header "All Tests Completed"
            print_info "Results saved in: $RESULTS_DIR"
            ;;

        run-custom)
            check_prerequisites
            build_images
            start_servers

            shift
            if [ $# -eq 0 ]; then
                print_error "No test parameters provided"
                print_info "Example: $0 run-custom --mode burst --messages 1000 --workers 20 --size medium"
                exit 1
            fi

            run_test "custom" "$@"
            monitor_servers
            collect_logs
            ;;

        help|--help|-h)
            usage
            ;;

        *)
            print_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
