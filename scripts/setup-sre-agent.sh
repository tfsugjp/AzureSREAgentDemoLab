#!/bin/bash

# Azure SRE Agent Demo Setup Script (Bash)
# This script validates SRE demo prerequisites and prints the next steps for deploying the Azure relay-backed overlay.
#
# Usage:
#   bash setup-sre-agent.sh -g <resource-group> -e <environment-name>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Parse arguments
RESOURCE_GROUP=""
ENVIRONMENT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -e|--environment-name)
            ENVIRONMENT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: setup-sre-agent.sh [OPTIONS]"
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

# Validate required arguments
if [[ -z "$RESOURCE_GROUP" || -z "$ENVIRONMENT_NAME" ]]; then
    log_error "Missing required arguments"
    echo "Run: bash setup-sre-agent.sh --help"
    exit 1
fi

log_info "Azure SRE Agent Demo Setup"
log_info "Resource Group: $RESOURCE_GROUP"
log_info "Environment: $ENVIRONMENT_NAME"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    log_error "Azure CLI (az) not found. Please install: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
log_success "Azure CLI found"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    log_error "Resource Group '$RESOURCE_GROUP' not found"
    exit 1
fi
RESOURCE_GROUP_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location --output tsv)
log_success "Resource Group exists ($RESOURCE_GROUP_LOCATION)"

# Check if Log Analytics workspace exists
LOG_ANALYTICS_WS=$(az monitor log-analytics workspace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$LOG_ANALYTICS_WS" ]]; then
    log_warn "No Log Analytics Workspace found. Please deploy infrastructure first."
    exit 1
fi
log_success "Log Analytics Workspace: $LOG_ANALYTICS_WS"

# Check if Application Insights exists
APP_INSIGHTS=$(az monitor app-insights component list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$APP_INSIGHTS" ]]; then
    log_warn "No Application Insights found. Please deploy infrastructure first."
    exit 1
fi
log_success "Application Insights: $APP_INSIGHTS"

# Check Container Apps Environment
CONTAINER_APPS_ENV=$(az containerapp env list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$CONTAINER_APPS_ENV" ]]; then
    log_warn "No Container Apps Environment found."
    exit 1
fi
log_success "Container Apps Environment: $CONTAINER_APPS_ENV"

# Check whether Container Apps are still running the provisioning placeholder image.
SAMPLE_IMAGE_URI="mcr.microsoft.com/dotnet/samples:aspnetapp"
SAMPLE_CONTAINER_APPS=$(az containerapp list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?properties.template.containers[0].image=='${SAMPLE_IMAGE_URI}'].[name, properties.template.containers[0].image]" \
    --output tsv 2>/dev/null || echo "")

if [[ -n "$SAMPLE_CONTAINER_APPS" ]]; then
    echo ""
    log_warn "Some Container Apps are still running the provisioning placeholder image."
    while IFS=$'\t' read -r app_name app_image; do
        log_warn "$app_name: $app_image"
    done <<< "$SAMPLE_CONTAINER_APPS"
    echo "Run 'azd deploy' after the SRE overlay to deploy the repository service images."
fi

echo ""
log_info "All prerequisites met. Ready for SRE resource deployment."
echo ""

# Output next steps
log_success "Setup validation complete!"
echo ""
echo "Next steps:"
echo "1. Create or identify your Logic App / Azure Function relay for incident routing"
echo "   Retrieve the full HTTP trigger callback URL (not the workflow overview URL) before deploying the SRE overlay:"
echo ""
echo "   LOGIC_APP_RESOURCE_ID=\"/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Logic/workflows/<logic-app-name>\""
echo "   LOGIC_APP_TRIGGER_NAME=\"When_an_HTTP_request_is_received\""
echo "   LOGIC_APP_CALLBACK_URL=\$(az rest --method post --url \"https://management.azure.com\${LOGIC_APP_RESOURCE_ID}/triggers/\${LOGIC_APP_TRIGGER_NAME}/listCallbackUrl?api-version=2019-05-01\" --query value --output tsv)"
echo ""
echo "2. Deploy the SRE overlay with explicit parameters:"
echo ""
echo "   az deployment group create --resource-group $RESOURCE_GROUP --template-file infra/sre-overlay.bicep --parameters \"environmentName=$ENVIRONMENT_NAME\" \"location=$RESOURCE_GROUP_LOCATION\" \"incidentRelayResourceId=<relay-resource-id>\" \"incidentRelayCallbackUrl=\$LOGIC_APP_CALLBACK_URL\" \"responseTimeThresholdMs=500\" \"failedRequestCountThreshold=5\""
echo "   Use infra/sre-overlay.bicep for SRE-only updates. Do not re-run infra/main.bicep just to update SRE resources, because it can reset Container Apps to the provisioning placeholder image."
echo "   The callback URL must contain '/triggers/' and 'sig=' or Azure Monitor will not invoke the Logic App."
echo ""
echo "3. If any app still uses mcr.microsoft.com/dotnet/samples:aspnetapp, deploy service images with: azd deploy"
echo ""
echo "4. Verify setup with:"
echo "   bash verify-sre-setup.sh -g $RESOURCE_GROUP -e $ENVIRONMENT_NAME"
echo ""
echo "For more details, see: docs/sre-agent-setup.md"
