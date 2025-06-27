#!/bin/bash

# Travel Agent - Teardown Script
# This script removes the travel agent and all its resources

set -e

# Configuration
AGENT_NAME="travel-agent"
ENVIRONMENT_NAME="dev"
RESOURCE_GROUP_NAME="rg-${AGENT_NAME}-${ENVIRONMENT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 [options]"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --force        Skip confirmation prompt"
    echo "  --help         Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0"
    echo "  $0 --force"
}

# Parse command line arguments
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            echo -e "${RED}❌ Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🗑️  Starting Travel Agent Teardown${NC}"
echo "Agent: $AGENT_NAME"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo ""

# Check Azure CLI authentication
echo -e "${BLUE}🔐 Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Check if resource group exists
echo -e "${BLUE}🔍 Checking if resource group exists...${NC}"
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Resource group '$RESOURCE_GROUP_NAME' does not exist. Nothing to tear down.${NC}"
    exit 0
fi

# Get resource group details
echo -e "${BLUE}📋 Resource group details:${NC}"
az group show --name "$RESOURCE_GROUP_NAME" --query "{Name:name, Location:location, Tags:tags}" -o table

# List resources in the group
echo -e "${BLUE}📋 Resources in the group:${NC}"
az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type, Location:location}" -o table

# Confirmation prompt
if [[ "$FORCE" == "false" ]]; then
    echo ""
    echo -e "${RED}⚠️  WARNING: This will permanently delete all resources in the resource group!${NC}"
    echo -e "${RED}   Resource Group: $RESOURCE_GROUP_NAME${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}❌ Teardown cancelled.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🗑️  Starting resource deletion...${NC}"

# Delete Container Apps first (they depend on other resources)
echo -e "${BLUE}🗑️  Deleting Container Apps...${NC}"
CONTAINER_APPS=$(az containerapp list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv)
for app in $CONTAINER_APPS; do
    echo "Deleting Container App: $app"
    az containerapp delete --name "$app" --resource-group "$RESOURCE_GROUP_NAME" --yes
done

# Delete Container Apps Environment
echo -e "${BLUE}🗑️  Deleting Container Apps Environment...${NC}"
CAE_NAME=$(az containerapp env list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
if [[ -n "$CAE_NAME" ]]; then
    echo "Deleting Container Apps Environment: $CAE_NAME"
    az containerapp env delete --name "$CAE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --yes
fi

# Delete Container Registry
echo -e "${BLUE}🗑️  Deleting Container Registry...${NC}"
ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
if [[ -n "$ACR_NAME" ]]; then
    echo "Deleting Container Registry: $ACR_NAME"
    az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --yes
fi

# Delete Managed Identities
echo -e "${BLUE}🗑️  Deleting Managed Identities...${NC}"
IDENTITIES=$(az identity list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv)
for identity in $IDENTITIES; do
    echo "Deleting Managed Identity: $identity"
    az identity delete --name "$identity" --resource-group "$RESOURCE_GROUP_NAME"
done

# Delete any remaining resources
echo -e "${BLUE}🗑️  Deleting remaining resources...${NC}"
REMAINING_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type}" -o tsv)
if [[ -n "$REMAINING_RESOURCES" ]]; then
    echo "Remaining resources:"
    echo "$REMAINING_RESOURCES"
    echo ""
    echo "Deleting remaining resources..."
    az resource delete --resource-group "$RESOURCE_GROUP_NAME" --yes
fi

# Delete the resource group
echo -e "${BLUE}🗑️  Deleting resource group...${NC}"
az group delete --name "$RESOURCE_GROUP_NAME" --yes

# Remove environment file if it exists
ENV_FILE=".env.${AGENT_NAME}"
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${BLUE}🗑️  Removing environment file...${NC}"
    rm "$ENV_FILE"
    echo -e "${GREEN}✅ Environment file removed: $ENV_FILE${NC}"
fi

echo -e "${GREEN}🎉 Travel Agent teardown completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Teardown Summary:${NC}"
echo "  Resource Group: $RESOURCE_GROUP_NAME - DELETED"
echo "  Container Apps: DELETED"
echo "  Container Apps Environment: DELETED"
echo "  Container Registry: DELETED"
echo "  Managed Identities: DELETED"
echo "  Environment File: REMOVED"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. If you want to redeploy, run: ./agents/travel-agent/infrastructure/deploy.sh"
echo "  2. If you want to create a new agent, run: ./scripts/create-agent.sh <agent-name>" 