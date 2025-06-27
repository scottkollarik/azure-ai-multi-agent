#!/bin/bash

# Azure AI Travel Agents Infrastructure Teardown Script
# This script removes all Azure resources to avoid costs

set -e  # Exit on any error

# Configuration
PROJECT_NAME="azure-ai-travel-agents"
ENVIRONMENT_NAME="dev"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT_NAME}"

echo "🗑️  Starting Azure Infrastructure Teardown"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT_NAME"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo ""

# Check Azure CLI authentication
echo "🔐 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not authenticated with Azure. Please run 'az login' first."
    exit 1
fi

# Check if resource group exists
echo "🔍 Checking if resource group exists..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo "❌ Resource group '$RESOURCE_GROUP_NAME' does not exist."
    echo "   No resources to teardown."
    exit 0
fi

# Display resources that will be deleted
echo "📋 Resources that will be deleted:"
az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type, Location:location}" -o table

echo ""
echo "⚠️  WARNING: This will permanently delete all resources in the resource group!"
echo "   This action cannot be undone."
echo ""

# Confirm deletion
read -p "Are you sure you want to delete all resources? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "❌ Teardown cancelled."
    exit 0
fi

echo ""
echo "🗑️  Deleting resource group and all resources..."
az group delete \
    --name "$RESOURCE_GROUP_NAME" \
    --yes \
    --no-wait

echo "✅ Resource group deletion initiated."
echo ""
echo "📊 Deletion Status:"
echo "  - Resource group deletion is running in the background"
echo "  - This may take several minutes to complete"
echo "  - You can monitor progress in Azure Portal"
echo ""
echo "🔗 Monitor in Azure Portal:"
echo "  https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME"
echo ""
echo "💰 Cost Impact:"
echo "  - All resources in the resource group will be deleted"
echo "  - No further charges will be incurred for these resources"
echo "  - Any data stored in these resources will be permanently lost"
echo ""
echo "✅ Teardown complete!" 