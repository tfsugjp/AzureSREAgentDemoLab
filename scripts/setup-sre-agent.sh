#!/bin/bash

# Azure SRE Agent Demo Setup Script (Bash)
# This script configures SRE resources including alerts, action groups, and Azure DevOps integration.
#
# Usage:
#   bash setup-sre-agent.sh -g <resource-group> -e <environment-name> -o <devops-org-url> -p <devops-project>

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
DEVOPS_ORG_URL=""
DEVOPS_PROJECT="SRE-Demo"
LOCATION="westus3"

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
        -o|--devops-org-url)
            DEVOPS_ORG_URL="$2"
            shift 2
            ;;
        -p|--devops-project)
            DEVOPS_PROJECT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: setup-sre-agent.sh [OPTIONS]"
            echo "Options:"
            echo "  -g, --resource-group <name>      Azure Resource Group (required)"
            echo "  -e, --environment-name <name>    Environment name (required)"
            echo "  -o, --devops-org-url <url>       Azure DevOps Org URL (required)"
            echo "  -p, --devops-project <project>   Azure DevOps Project (default: SRE-Demo)"
            echo "  -l, --location <location>        Azure region (default: westus3)"
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
if [[ -z "$RESOURCE_GROUP" || -z "$ENVIRONMENT_NAME" || -z "$DEVOPS_ORG_URL" ]]; then
    log_error "Missing required arguments"
    echo "Run: bash setup-sre-agent.sh --help"
    exit 1
fi

log_info "Azure SRE Agent Demo Setup"
log_info "Resource Group: $RESOURCE_GROUP"
log_info "Environment: $ENVIRONMENT_NAME"
log_info "DevOps Org: $DEVOPS_ORG_URL"
log_info "DevOps Project: $DEVOPS_PROJECT"
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
log_success "Resource Group exists"

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

echo ""
log_info "All prerequisites met. Ready for SRE resource deployment."
echo ""

# Output next steps
log_success "Setup validation complete!"
echo ""
echo "Next steps:"
echo "1. Update infra/main.parameters.json with SRE parameters:"
echo "   - enableSreDemo: true"
echo "   - azureDevOpsOrgUrl: $DEVOPS_ORG_URL"
echo "   - azureDevOpsProjectName: $DEVOPS_PROJECT"
echo ""
echo "2. Deploy with azd:"
echo "   azd env set enableSreDemo true"
echo "   azd env set azureDevOpsOrgUrl \"$DEVOPS_ORG_URL\""
echo "   azd env set azureDevOpsProjectName \"$DEVOPS_PROJECT\""
echo "   azd up"
echo ""
echo "3. Verify setup with:"
echo "   bash verify-sre-setup.sh -g $RESOURCE_GROUP -e $ENVIRONMENT_NAME"
echo ""
echo "For more details, see: docs/sre-agent-setup.md"
