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

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

require_positive_integer() {
    local value="$1"
    local name="$2"

    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        log_error "$name must be a positive integer"
        exit 1
    fi
}

derive_health_endpoint() {
    local endpoint="$1"

    if [[ "$endpoint" =~ ^(https?://[^/]+) ]]; then
        printf '%s/health' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

derive_warmup_endpoints() {
    local endpoint="$1"
    local preferred_health_endpoint="$2"

    if [[ -n "$preferred_health_endpoint" ]]; then
        printf '%s\n' "$preferred_health_endpoint"
        printf '%s\n' "$endpoint"
        return 0
    fi

    local health_endpoint
    health_endpoint=$(derive_health_endpoint "$endpoint") || return 1

    printf '%s\n' "$health_endpoint"
    printf '%s/ready\n' "$health_endpoint"
    printf '%s\n' "$endpoint"
}

probe_url() {
    local url="$1"
    local timeout="$2"
    local status_code
    local curl_exit_code

    set +e

    if [[ -n "$ACCESS_TOKEN" ]]; then
        status_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" -H "Authorization: Bearer $ACCESS_TOKEN" "$url")
        curl_exit_code=$?
    else
        status_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url")
        curl_exit_code=$?
    fi

    set -e

    echo "$curl_exit_code:$status_code"
}

# Parse arguments
ENDPOINT=""
HEALTH_ENDPOINT=""
CONCURRENT=50
DURATION=60
INTERVAL=5
ACCESS_TOKEN=""
CONNECTIVITY_TIMEOUT=15
WARMUP_ATTEMPTS=3

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        --health-endpoint)
            HEALTH_ENDPOINT="$2"
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
        --access-token)
            ACCESS_TOKEN="$2"
            shift 2
            ;;
        --timeout)
            CONNECTIVITY_TIMEOUT="$2"
            shift 2
            ;;
        --warmup-attempts)
            WARMUP_ATTEMPTS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: trigger-incident-demo.sh [OPTIONS]"
            echo "Options:"
            echo "  -e, --endpoint <url>       Order Service workload endpoint, for example https://<app>/api/orders (required)"
            echo "      --health-endpoint <url> Optional health endpoint. Defaults to https://<host>/health derived from --endpoint"
            echo "  -c, --concurrent <num>     Number of concurrent requests (default: 50)"
            echo "  -d, --duration <seconds>   Test duration in seconds (default: 60)"
            echo "  -i, --interval <seconds>   Interval between batches (default: 5)"
            echo "      --access-token <token> Optional Microsoft Entra bearer token for authenticated APIs"
            echo "      --timeout <seconds>    Timeout for connectivity probes (default: 15)"
            echo "      --warmup-attempts <n>  Number of health probe retries before failing (default: 3)"
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

require_positive_integer "$CONCURRENT" "Concurrent"
require_positive_integer "$DURATION" "Duration"
require_positive_integer "$INTERVAL" "Interval"
require_positive_integer "$CONNECTIVITY_TIMEOUT" "Timeout"
require_positive_integer "$WARMUP_ATTEMPTS" "Warmup attempts"

if [[ -z "$HEALTH_ENDPOINT" ]]; then
    if ! HEALTH_ENDPOINT=$(derive_health_endpoint "$ENDPOINT"); then
        log_error "Endpoint must be an absolute URL: $ENDPOINT"
        exit 1
    fi
fi

mapfile -t WARMUP_ENDPOINTS < <(derive_warmup_endpoints "$ENDPOINT" "$HEALTH_ENDPOINT")

log_info "Azure SRE Agent Demo - Incident Trigger"
log_info "Endpoint: $ENDPOINT"
log_info "Health endpoint: $HEALTH_ENDPOINT"
log_info "Warm-up candidates: ${WARMUP_ENDPOINTS[*]}"
log_info "Concurrent requests: $CONCURRENT"
log_info "Total duration: ${DURATION}s"
log_info "Batch interval: ${INTERVAL}s"
log_info "Connectivity timeout: ${CONNECTIVITY_TIMEOUT}s"
if [[ -n "$ACCESS_TOKEN" ]]; then
    log_info "Bearer token provided: yes"
else
    log_info "Bearer token provided: no"
fi
echo ""

log_info "Warming up Container App via health endpoint..."
HEALTH_READY=false
for attempt in $(seq 1 "$WARMUP_ATTEMPTS"); do
    for warmup_endpoint in "${WARMUP_ENDPOINTS[@]}"; do
        IFS=':' read -r curl_rc status_code <<< "$(probe_url "$warmup_endpoint" "$CONNECTIVITY_TIMEOUT")"

        if [[ "$curl_rc" -eq 0 && "$status_code" =~ ^[23][0-9][0-9]$ ]]; then
            log_success "Warm-up endpoint reachable on attempt ${attempt}: ${warmup_endpoint}"
            HEALTH_READY=true
            break 2
        fi

        if [[ "$warmup_endpoint" == "$ENDPOINT" && "$curl_rc" -eq 0 && ( "$status_code" == "401" || "$status_code" == "403" ) ]]; then
            log_warn "Warm-up reached workload endpoint on attempt ${attempt} but authentication is required (HTTP ${status_code})."
            HEALTH_READY=true
            break 2
        fi

        if [[ "$curl_rc" -eq 28 ]]; then
            log_warn "Warm-up probe ${warmup_endpoint} attempt ${attempt}/${WARMUP_ATTEMPTS} timed out after ${CONNECTIVITY_TIMEOUT}s"
        elif [[ "$curl_rc" -ne 0 ]]; then
            log_warn "Warm-up probe ${warmup_endpoint} attempt ${attempt}/${WARMUP_ATTEMPTS} failed with curl exit code ${curl_rc}"
        else
            log_warn "Warm-up endpoint ${warmup_endpoint} returned HTTP ${status_code} on attempt ${attempt}/${WARMUP_ATTEMPTS}"
        fi
    done
done

if [[ "$HEALTH_READY" != true ]]; then
    log_error "Cannot warm up Container App using any candidate endpoint."
    log_error "Candidates tried: ${WARMUP_ENDPOINTS[*]}"
    log_error "Try supplying --health-endpoint explicitly, checking the deployed app routes, or increasing --timeout."
    exit 1
fi

log_info "Probing workload endpoint before starting load..."
IFS=':' read -r endpoint_curl_rc endpoint_status_code <<< "$(probe_url "$ENDPOINT" "$CONNECTIVITY_TIMEOUT")"

if [[ "$endpoint_curl_rc" -eq 0 ]]; then
    if [[ "$endpoint_status_code" =~ ^[23][0-9][0-9]$ ]]; then
        log_success "Workload endpoint reachable"
    elif [[ "$endpoint_status_code" == "401" || "$endpoint_status_code" == "403" ]]; then
        log_error "Workload endpoint returned HTTP ${endpoint_status_code}. Authentication is enabled for /api/orders."
        log_error "Provide --access-token or redeploy with disableAuthentication=true for workshop scenarios."
        exit 1
    elif [[ "$endpoint_status_code" == "404" ]]; then
        log_error "Workload endpoint returned HTTP 404. Confirm the endpoint path is correct, for example /api/orders."
        exit 1
    else
        log_warn "Workload endpoint returned HTTP ${endpoint_status_code}. Continuing because the app is reachable and the load test may still be useful."
    fi
elif [[ "$endpoint_curl_rc" == "28" ]]; then
    log_warn "Workload probe timed out after ${CONNECTIVITY_TIMEOUT}s. Continuing because the health endpoint is reachable and the app may still be cold-starting."
else
    log_warn "Workload probe failed with curl exit code ${endpoint_curl_rc}. Continuing because the health endpoint is reachable."
fi

log_info "Starting synthetic load test..."
log_info "⏱ This will generate high request volume to trigger alerts"
echo ""

send_requests() {
    local pids=()
    
    for i in $(seq 1 $CONCURRENT); do
        (
            if [[ -n "$ACCESS_TOKEN" ]]; then
                curl -sS --max-time 30 -H "Authorization: Bearer $ACCESS_TOKEN" -X GET "$ENDPOINT" > /dev/null 2>&1 || true
            else
                curl -sS --max-time 30 -X GET "$ENDPOINT" > /dev/null 2>&1 || true
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

# Calculate number of iterations
ITERATIONS=$(((DURATION + INTERVAL - 1) / INTERVAL))

# Send load
for i in $(seq 1 $ITERATIONS); do
    ELAPSED=$((i * INTERVAL))
    if [[ "$ELAPSED" -gt "$DURATION" ]]; then
        ELAPSED="$DURATION"
    fi
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
log_info "3. Check Azure DevOps work items or GitHub issues in your configured destination"
log_info "4. Run: bash verify-sre-setup.sh to check alert status"
