#!/bin/bash

# Azure SRE Agent Demo - Verification Script (Bash)
# Verifies SRE resources are correctly deployed and configured
#
# Usage:
#   bash verify-sre-setup.sh -g <resource-group> -e <environment-name>

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

FAILURES=0

record_failure() {
    FAILURES=$((FAILURES + 1))
}

# Parse arguments
RESOURCE_GROUP=""
ENVIRONMENT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
        -e|--environment-name) ENVIRONMENT_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: verify-sre-setup.sh [OPTIONS]"
            echo "Options:"
            echo "  -g, --resource-group <name>      Azure Resource Group (required)"
            echo "  -e, --environment-name <name>    Environment name (required)"
            echo "  -h, --help                       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$ENVIRONMENT_NAME" ]]; then
    log_error "Missing required arguments"
    echo "Run: bash verify-sre-setup.sh --help"
    exit 1
fi

log_info "Azure SRE Agent Demo - Verification"
log_info "Resource Group: $RESOURCE_GROUP"
log_info "Environment: $ENVIRONMENT_NAME"
echo ""

# Check 1: Log Analytics Workspace
log_info "Checking Log Analytics Workspace..."
LOG_ANALYTICS_WS_NAME=$(az monitor log-analytics workspace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" \
    --output tsv 2>/dev/null || echo "")
LOG_ANALYTICS_WS_ID=$(az monitor log-analytics workspace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].customerId" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$LOG_ANALYTICS_WS_NAME" || -z "$LOG_ANALYTICS_WS_ID" ]]; then
    log_error "No Log Analytics Workspace found"
    record_failure
else
    log_success "Log Analytics Workspace: $LOG_ANALYTICS_WS_NAME"
fi

# Check 2: Application Insights
log_info "Checking Application Insights..."
APP_INSIGHTS=$(az monitor app-insights component list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$APP_INSIGHTS" ]]; then
    log_error "No Application Insights found"
    record_failure
else
    log_success "Application Insights: $APP_INSIGHTS"
fi

# Check 3: Alert Rules
log_info "Checking Alert Rules..."
ALERT_COUNT=$(az monitor metrics alert list \
    --resource-group "$RESOURCE_GROUP" \
    --query "length(@)" \
    --output tsv 2>/dev/null || echo "0")

if [[ "$ALERT_COUNT" -eq 0 ]]; then
    log_warn "No metric alerts found. Deploy the SRE overlay with infra/sre-overlay.bicep"
else
    log_success "Found $ALERT_COUNT metric alert(s)"
    az monitor metrics alert list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].[name, properties.severity, properties.enabled]" \
        --output table
fi

# Check 4: Action Groups
log_info "Checking Action Groups..."
ACTION_GROUP=$(az monitor action-group list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?contains(name, 'ag-sre')].name" \
    --output tsv 2>/dev/null | head -1 || echo "")

if [[ -z "$ACTION_GROUP" ]]; then
    log_warn "No SRE Action Group found. Deploy the SRE overlay with infra/sre-overlay.bicep"
    record_failure
else
    log_success "Action Group: $ACTION_GROUP"

    ACTION_GROUP_JSON=$(az monitor action-group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACTION_GROUP" \
        --output json 2>/dev/null || echo "")

    if [[ -n "$ACTION_GROUP_JSON" ]]; then
        LOGIC_APP_RECEIVER_COUNT=$(echo "$ACTION_GROUP_JSON" | jq '.logicAppReceivers | length')
        if [[ "$LOGIC_APP_RECEIVER_COUNT" -eq 0 ]]; then
            log_warn "Action Group does not contain any Logic App receivers"
        else
            for index in $(seq 0 $((LOGIC_APP_RECEIVER_COUNT - 1))); do
                RECEIVER_NAME=$(echo "$ACTION_GROUP_JSON" | jq -r ".logicAppReceivers[$index].name")
                RECEIVER_RESOURCE_ID=$(echo "$ACTION_GROUP_JSON" | jq -r ".logicAppReceivers[$index].resourceId")
                RECEIVER_CALLBACK_URL=$(echo "$ACTION_GROUP_JSON" | jq -r ".logicAppReceivers[$index].callbackUrl")

                log_info "Validating Logic App receiver callback URL for $RECEIVER_NAME..."
                WORKFLOW_JSON=$(az resource show --ids "$RECEIVER_RESOURCE_ID" --output json 2>/dev/null || echo "")
                TRIGGER_NAME=$(echo "$WORKFLOW_JSON" | jq -r '.properties.definition.triggers | keys[0] // empty')
                EXPECTED_CALLBACK_URL=$(az rest \
                    --method post \
                    --url "https://management.azure.com${RECEIVER_RESOURCE_ID}/triggers/${TRIGGER_NAME}/listCallbackUrl?api-version=2019-05-01" \
                    --query value \
                    --output tsv 2>/dev/null || echo "")

                if [[ -z "$EXPECTED_CALLBACK_URL" ]]; then
                    log_error "Unable to retrieve the Logic App trigger callback URL for $RECEIVER_RESOURCE_ID"
                    record_failure
                elif [[ "$RECEIVER_CALLBACK_URL" != "$EXPECTED_CALLBACK_URL" ]]; then
                    log_error "Logic App receiver callback URL does not match the trigger callback URL. Use listCallbackUrl output, not the Logic App overview URL."
                    record_failure
                else
                    log_success "Logic App receiver callback URL matches the trigger callback URL"
                fi
            done
        fi
    else
        log_warn "Unable to inspect Action Group details"
        record_failure
    fi
fi

# Check 5: Container Apps
log_info "Checking Container Apps..."
SAMPLE_IMAGE_URI="mcr.microsoft.com/dotnet/samples:aspnetapp"
CONTAINER_APPS=$(az containerapp list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{name: name, provisioning: properties.provisioningState, image: properties.template.containers[0].image}" \
    --output json)

if [[ $(echo "$CONTAINER_APPS" | jq 'length') -eq 0 ]]; then
    log_error "No Container Apps found"
    record_failure
else
    while IFS=$'\t' read -r app_name provisioning image; do
        if [[ "$provisioning" == "Succeeded" ]]; then
            log_success "$app_name: Provisioning State = Succeeded"
        else
            log_warn "$app_name: Provisioning State = $provisioning"
            record_failure
        fi

        if [[ "$image" == "$SAMPLE_IMAGE_URI" ]]; then
            log_error "$app_name: Still running provisioning placeholder image ($SAMPLE_IMAGE_URI). Run 'azd deploy' to deploy repository service images."
            record_failure
        else
            log_success "$app_name: Image = $image"
        fi
    done < <(echo "$CONTAINER_APPS" | jq -r '.[] | [.name, .provisioning, .image] | @tsv')
fi

# Check 6: Test query on Log Analytics
if [[ -n "$LOG_ANALYTICS_WS_ID" ]]; then
    log_info "Testing Log Analytics queries..."
    QUERY_RESULT=$(az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WS_ID" \
        --analytics-query "AppRequests | where TimeGenerated > ago(1h) | summarize RequestCount = sum(ItemCount)" \
        --output json 2>/dev/null | jq -r '.[0][0]' || echo "0")

    if [[ "$QUERY_RESULT" -gt 0 ]]; then
        log_success "Log Analytics working ($QUERY_RESULT requests in last hour)"
    else
        log_warn "No recent request telemetry in Log Analytics"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$FAILURES" -eq 0 ]]; then
    log_success "Verification Report"
else
    log_warn "Verification Report"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "✓ Prerequisites: All Azure resources present"
    echo "✓ Status: SRE Agent demo infrastructure ready"
else
    echo "✗ One or more prerequisite checks failed"
    echo "✗ Status: SRE Agent demo infrastructure is not ready"
fi
echo ""
echo "To run the demo:"
echo "1. Generate synthetic load:"
echo "   bash trigger-incident-demo.sh -e <order-service-endpoint>"
echo ""
echo "2. Monitor alert status:"
echo "   az monitor metrics alert list --resource-group $RESOURCE_GROUP"
echo ""
echo "3. Check the work item or issue in your configured downstream destination"
echo ""
echo "4. See detailed guide: docs/sre-scenario-20min.md"
echo ""

if [[ "$FAILURES" -ne 0 ]]; then
    exit 1
fi
