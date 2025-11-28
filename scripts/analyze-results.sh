#!/bin/bash
# PrixFixe Stress Test Results Analyzer
# Analyzes and generates reports from stress test results

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

RESULTS_DIR="stress-test/results"

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

print_header() {
    echo ""
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo ""
}

# Function to analyze a single JSON result file
analyze_result() {
    local file=$1

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        print_warning "jq not installed, showing raw JSON"
        cat "$file"
        return 0
    fi

    print_header "Analysis: $(basename "$file")"

    # Extract key metrics
    local test_type=$(jq -r '.test_type // "unknown"' "$file")
    local servers=$(jq -r '.servers | join(", ")' "$file")
    local message_size=$(jq -r '.message_size // 0' "$file")

    echo "Test Type:         $test_type"
    echo "Servers:           $servers"
    echo "Message Size:      $((message_size / 1024)) KB"
    echo ""

    # Metrics
    local total=$(jq -r '.metrics.total_messages // 0' "$file")
    local successful=$(jq -r '.metrics.successful_messages // 0' "$file")
    local failed=$(jq -r '.metrics.failed_messages // 0' "$file")
    local conn_errors=$(jq -r '.metrics.connection_errors // 0' "$file")
    local duration=$(jq -r '.metrics.duration_seconds // 0' "$file")
    local msg_per_sec=$(jq -r '.metrics.messages_per_second // 0' "$file")
    local total_mb=$(jq -r '.metrics.total_bytes_sent // 0' "$file")
    local avg_response=$(jq -r '.metrics.avg_response_time_ms // 0' "$file")
    local min_response=$(jq -r '.metrics.min_response_time_ms // 0' "$file")
    local max_response=$(jq -r '.metrics.max_response_time_ms // 0' "$file")

    # Calculate success rate
    local success_rate=0
    if [ "$total" -gt 0 ]; then
        success_rate=$(echo "scale=2; ($successful / $total) * 100" | bc)
    fi

    # Convert total MB
    total_mb=$(echo "scale=2; $total_mb / 1048576" | bc)

    echo "Messages:"
    echo "  Total:           $total"
    echo "  Successful:      $successful"
    echo "  Failed:          $failed"
    echo "  Conn Errors:     $conn_errors"
    echo "  Success Rate:    ${success_rate}%"
    echo ""

    echo "Performance:"
    echo "  Duration:        ${duration}s"
    echo "  Messages/Sec:    $msg_per_sec"
    echo "  Total Data:      ${total_mb} MB"
    echo ""

    echo "Response Times:"
    echo "  Average:         ${avg_response} ms"
    echo "  Minimum:         ${min_response} ms"
    echo "  Maximum:         ${max_response} ms"
    echo ""

    # Color-coded status
    if [ "$failed" -eq 0 ] && [ "$conn_errors" -eq 0 ]; then
        print_success "Status: PASSED - No errors"
    elif [ "$success_rate" -gt 95 ]; then
        print_warning "Status: WARNING - Success rate: ${success_rate}%"
    else
        print_error "Status: FAILED - Success rate: ${success_rate}%"
    fi
}

# Function to generate summary report
generate_summary() {
    print_header "Test Results Summary"

    if ! command -v jq &> /dev/null; then
        print_error "jq is required for summary generation"
        print_info "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        return 1
    fi

    local json_files=$(find "$RESULTS_DIR" -name "*.json" -type f 2>/dev/null | sort)

    if [ -z "$json_files" ]; then
        print_warning "No result files found in $RESULTS_DIR"
        return 0
    fi

    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local total_messages=0
    local total_successful=0
    local total_failed=0

    echo "Test Results:"
    echo ""
    printf "%-30s %-12s %-12s %-12s %-10s\n" "Test Name" "Total Msgs" "Success" "Failed" "Rate"
    printf "%-30s %-12s %-12s %-12s %-10s\n" "----------" "----------" "-------" "------" "----"

    while IFS= read -r file; do
        local name=$(basename "$file" .json)
        local total=$(jq -r '.metrics.total_messages // 0' "$file")
        local success=$(jq -r '.metrics.successful_messages // 0' "$file")
        local failed=$(jq -r '.metrics.failed_messages // 0' "$file")

        local rate=0
        if [ "$total" -gt 0 ]; then
            rate=$(echo "scale=1; ($success / $total) * 100" | bc)
        fi

        printf "%-30s %-12s %-12s %-12s %-10s%%\n" \
            "${name:0:29}" "$total" "$success" "$failed" "$rate"

        total_tests=$((total_tests + 1))
        total_messages=$((total_messages + total))
        total_successful=$((total_successful + success))
        total_failed=$((total_failed + failed))

        if [ "$failed" -eq 0 ]; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
    done <<< "$json_files"

    echo ""
    echo "Overall Statistics:"
    echo "  Total Test Runs:     $total_tests"
    echo "  Passed:              $passed_tests"
    echo "  Failed:              $failed_tests"
    echo "  Total Messages:      $total_messages"
    echo "  Total Successful:    $total_successful"
    echo "  Total Failed:        $total_failed"

    if [ "$total_messages" -gt 0 ]; then
        local overall_rate=$(echo "scale=2; ($total_successful / $total_messages) * 100" | bc)
        echo "  Overall Success:     ${overall_rate}%"
    fi
}

# Function to compare results
compare_results() {
    local file1=$1
    local file2=$2

    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        print_error "One or both files not found"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is required for comparison"
        return 1
    fi

    print_header "Comparing Results"
    echo "File 1: $(basename "$file1")"
    echo "File 2: $(basename "$file2")"
    echo ""

    local msg_sec_1=$(jq -r '.metrics.messages_per_second // 0' "$file1")
    local msg_sec_2=$(jq -r '.metrics.messages_per_second // 0' "$file2")

    local avg_resp_1=$(jq -r '.metrics.avg_response_time_ms // 0' "$file1")
    local avg_resp_2=$(jq -r '.metrics.avg_response_time_ms // 0' "$file2")

    local success_1=$(jq -r '.metrics.successful_messages // 0' "$file1")
    local success_2=$(jq -r '.metrics.successful_messages // 0' "$file2")

    printf "%-25s %-15s %-15s %-15s\n" "Metric" "File 1" "File 2" "Difference"
    printf "%-25s %-15s %-15s %-15s\n" "------" "------" "------" "----------"

    local diff_msg_sec=$(echo "scale=2; $msg_sec_2 - $msg_sec_1" | bc)
    printf "%-25s %-15s %-15s %-15s\n" "Messages/Second" "$msg_sec_1" "$msg_sec_2" "$diff_msg_sec"

    local diff_resp=$(echo "scale=2; $avg_resp_2 - $avg_resp_1" | bc)
    printf "%-25s %-15s %-15s %-15s\n" "Avg Response (ms)" "$avg_resp_1" "$avg_resp_2" "$diff_resp"

    local diff_success=$((success_2 - success_1))
    printf "%-25s %-15s %-15s %-15s\n" "Successful Messages" "$success_1" "$success_2" "$diff_success"
}

# Function to list available results
list_results() {
    print_header "Available Result Files"

    if [ ! -d "$RESULTS_DIR" ]; then
        print_warning "Results directory not found: $RESULTS_DIR"
        return 0
    fi

    local json_files=$(find "$RESULTS_DIR" -name "*.json" -type f 2>/dev/null | sort)

    if [ -z "$json_files" ]; then
        print_warning "No result files found"
        return 0
    fi

    local count=0
    while IFS= read -r file; do
        count=$((count + 1))
        local size=$(ls -lh "$file" | awk '{print $5}')
        local date=$(ls -l "$file" | awk '{print $6, $7, $8}')
        echo "$count. $(basename "$file") - $size - $date"
    done <<< "$json_files"

    echo ""
    print_info "Total: $count result file(s)"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    list                List all available result files
    analyze FILE        Analyze a specific result file
    summary             Generate summary of all results
    compare FILE1 FILE2 Compare two result files
    latest              Analyze the most recent result file

Examples:
    $0 list
    $0 analyze stress-test/results/20241127-120000-burst.json
    $0 summary
    $0 compare file1.json file2.json
    $0 latest

EOF
}

# Main execution
main() {
    local command=${1:-help}

    case "$command" in
        list)
            list_results
            ;;

        analyze)
            if [ -z "$2" ]; then
                print_error "No file specified"
                usage
                exit 1
            fi
            analyze_result "$2"
            ;;

        summary)
            generate_summary
            ;;

        compare)
            if [ -z "$2" ] || [ -z "$3" ]; then
                print_error "Two files required for comparison"
                usage
                exit 1
            fi
            compare_results "$2" "$3"
            ;;

        latest)
            local latest=$(find "$RESULTS_DIR" -name "*.json" -type f 2>/dev/null | sort | tail -1)
            if [ -z "$latest" ]; then
                print_warning "No result files found"
                exit 0
            fi
            analyze_result "$latest"
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
