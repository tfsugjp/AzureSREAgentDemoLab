#!/bin/bash

# Azure SRE Agent Demo - Incident Trigger Script (Bash)
# Generates synthetic load to trigger alerts for the SRE Agent demo
#
# Usage:
#   bash trigger-incident-demo.sh -e <order-service-endpoint> [-c <concurrent>] [-d <duration>]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Parse arguments
ENDPOINT=""
CONCURRENT=50
DURATION=60
INTERVAL=5

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        -c|--concurrent)
            CONCURRENT="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: trigger-incident-demo.sh [OPTIONS]"
            echo "Options:"
            echo "  -e, --endpoint <url>       Order Service endpoint (required)"
            echo "  -c, --concurrent <num>     Number of concurrent requests (default: 50)"
            echo "  -d, --duration <seconds>   Test duration in seconds (default: 60)"
            echo "  -i, --interval <seconds>   Interval between batches (default: 5)"
            echo "  -h, --help                 Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$ENDPOINT" ]]; then
    log_error "Missing required argument: --endpoint"
    echo "Run: bash trigger-incident-demo.sh --help"
    exit 1
fi

# Validate endpoint
if ! curl -s --max-time 2 "$ENDPOINT" > /dev/null 2>&1; then
    log_error "Cannot reach endpoint: $ENDPOINT"
    exit 1
fi

log_info "Azure SRE Agent Demo - Incident Trigger"
log_info "Endpoint: $ENDPOINT"
log_info "Concurrent requests: $CONCURRENT"
log_info "Total duration: ${DURATION}s"
log_info "Batch interval: ${INTERVAL}s"
echo ""

log_info "Starting synthetic load test..."
log_info "⏱ This will generate high request volume to trigger alerts"
echo ""

send_requests() {
    local pids=()
    
    for i in $(seq 1 $CONCURRENT); do
        (
            timeout 10 curl -s -X GET "$ENDPOINT" > /dev/null 2>&1 || true
        ) &
        pids+=($!)
    done
    
    # Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

# Calculate number of iterations
ITERATIONS=$((DURATION / INTERVAL))

# Send load
for i in $(seq 1 $ITERATIONS); do
    ELAPSED=$((i * INTERVAL))
    PERCENT=$(( (ELAPSED * 100) / DURATION ))
    
    printf "\r📊 Progress: ${PERCENT}%% (${ELAPSED}s / ${DURATION}s) - Sending ${CONCURRENT} requests..."
    
    send_requests
    
    if [[ $i -lt $ITERATIONS ]]; then
        sleep $INTERVAL
    fi
done

echo ""
echo ""
log_success "Load test complete!"
echo ""
log_info "Total requests sent: approximately $((CONCURRENT * ITERATIONS))"
log_info "Expected latency spike should appear in Application Insights within 2-3 minutes"
log_info ""
log_info "Next steps:"
log_info "1. Wait 2-3 minutes for metrics to be ingested"
log_info "2. Check Azure Monitor Alerts: az monitor metrics alert list"
log_info "3. Check Azure DevOps for work item: $ENDPOINT/../devops"
log_info "4. Run: bash verify-sre-setup.sh to check alert status"
