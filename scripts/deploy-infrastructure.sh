#!/bin/bash

# Azure AI Travel Agents Infrastructure Deployment Script
# This script creates all necessary Azure resources for the project

set -e  # Exit on any error

# Configuration
PROJECT_NAME="azure-ai-travel-agents"
ENVIRONMENT_NAME="dev"
LOCATION="eastus2"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT_NAME}"

# Standard Azure resource abbreviations (from abbreviations.json)
ABBR_RG="rg-"
ABBR_COG="cog-"
ABBR_CR="cr"
ABBR_CAE="cae-"
ABBR_CA="ca-"
ABBR_ID="id-"
ABBR_LOG="log-"
ABBR_APPI="appi-"
ABBR_DASH="dash-"

# Generate unique resource token
RESOURCE_TOKEN=$(az account show --query id -o tsv | cut -c1-8)

# Tags for all resources
TAGS=(
    "Project=${PROJECT_NAME}"
    "Environment=${ENVIRONMENT_NAME}"
    "ResourceType=AI-Travel-Agents"
    "ManagedBy=Azure-CLI"
    "Owner=Development"
    "CostCenter=AI-Development"
    "DeploymentDate=$(date +%Y-%m-%d)"
)

# Convert tags array to Azure CLI format
TAGS_STRING=""
for tag in "${TAGS[@]}"; do
    TAGS_STRING="$TAGS_STRING $tag"
done

echo "🚀 Starting Azure Infrastructure Deployment"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT_NAME"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo ""

# Check Azure CLI authentication
echo "🔐 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not authenticated with Azure. Please run 'az login' first."
    exit 1
fi

# Create resource group
echo "📦 Creating resource group..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags $TAGS_STRING

echo "✅ Resource group created: $RESOURCE_GROUP_NAME"

# Create Azure OpenAI Service
echo "🤖 Creating Azure OpenAI Service..."
OPENAI_NAME="${ABBR_COG}${RESOURCE_TOKEN}"
az cognitiveservices account create \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --kind "AIServices" \
    --sku "S0" \
    --custom-subdomain-name "$OPENAI_NAME" \
    --tags $TAGS_STRING

# Deploy GPT-4o-mini model
echo "📝 Deploying GPT-4o-mini model..."
az cognitiveservices account deployment create \
    --name "gpt-4o-mini" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$OPENAI_NAME" \
    --model-format "OpenAI" \
    --model-name "gpt-4o-mini" \
    --model-version "2024-07-18" \
    --scale-settings-capacity 50 \
    --scale-settings-scale-type "Standard"

echo "✅ Azure OpenAI Service created: $OPENAI_NAME"

# Create Azure Container Registry
echo "📦 Creating Azure Container Registry..."
ACR_NAME="${ABBR_CR}${PROJECT_NAME}${RESOURCE_TOKEN}"
az acr create \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku "Basic" \
    --admin-enabled true \
    --tags $TAGS_STRING

echo "✅ Container Registry created: $ACR_NAME"

# Create Log Analytics Workspace
echo "📊 Creating Log Analytics Workspace..."
LOG_WORKSPACE_NAME="${ABBR_LOG}${PROJECT_NAME}${RESOURCE_TOKEN}"
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_WORKSPACE_NAME" \
    --location "$LOCATION" \
    --tags $TAGS_STRING

echo "✅ Log Analytics Workspace created: $LOG_WORKSPACE_NAME"

# Create Application Insights
echo "🔍 Creating Application Insights..."
APP_INSIGHTS_NAME="${ABBR_APPI}${PROJECT_NAME}${RESOURCE_TOKEN}"
az monitor app-insights component create \
    --app "$APP_INSIGHTS_NAME" \
    --location "$LOCATION" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --application-type "web" \
    --workspace "$LOG_WORKSPACE_NAME" \
    --tags $TAGS_STRING

echo "✅ Application Insights created: $APP_INSIGHTS_NAME"

# Create Container Apps Environment
echo "🐳 Creating Container Apps Environment..."
CAE_NAME="${ABBR_CAE}${PROJECT_NAME}${RESOURCE_TOKEN}"
az containerapp env create \
    --name "$CAE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --logs-workspace-id "$(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP_NAME --workspace-name $LOG_WORKSPACE_NAME --query customerId -o tsv)" \
    --tags $TAGS_STRING

echo "✅ Container Apps Environment created: $CAE_NAME"

# Create User-Assigned Managed Identities
echo "🔐 Creating Managed Identities..."

# API Identity
API_IDENTITY_NAME="${ABBR_ID}api-${PROJECT_NAME}${RESOURCE_TOKEN}"
az identity create \
    --name "$API_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags $TAGS_STRING

# UI Identity
UI_IDENTITY_NAME="${ABBR_ID}ui-${PROJECT_NAME}${RESOURCE_TOKEN}"
az identity create \
    --name "$UI_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags $TAGS_STRING

echo "✅ Managed Identities created"

# Assign roles to managed identities
echo "🔑 Assigning roles to managed identities..."

# Get principal IDs
API_PRINCIPAL_ID=$(az identity show --name "$API_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query principalId -o tsv)
UI_PRINCIPAL_ID=$(az identity show --name "$UI_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query principalId -o tsv)

# Assign OpenAI User role to API identity
az role assignment create \
    --assignee "$API_PRINCIPAL_ID" \
    --role "Cognitive Services OpenAI User" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.CognitiveServices/accounts/$OPENAI_NAME"

# Assign ACR Pull role to both identities
az role assignment create \
    --assignee "$API_PRINCIPAL_ID" \
    --role "AcrPull" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"

az role assignment create \
    --assignee "$UI_PRINCIPAL_ID" \
    --role "AcrPull" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"

echo "✅ Roles assigned"

# Get outputs for environment configuration
echo "📋 Gathering configuration outputs..."

OPENAI_ENDPOINT=$(az cognitiveservices account show --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query properties.endpoint -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query loginServer -o tsv)
APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query connectionString -o tsv)
API_CLIENT_ID=$(az identity show --name "$API_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)

# Create .env file with Azure configuration
echo "📝 Creating .env file with Azure configuration..."
cat > .env.azure << EOF
# Azure Infrastructure Configuration
# Generated on $(date)

# Resource Group
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP_NAME
AZURE_LOCATION=$LOCATION

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini
LLM_PROVIDER=azure-openai

# Container Registry
AZURE_CONTAINER_REGISTRY_ENDPOINT=$ACR_LOGIN_SERVER

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING

# Managed Identities
AZURE_CLIENT_ID=$API_CLIENT_ID

# Container Apps Environment
AZURE_CONTAINER_APPS_ENVIRONMENT=$CAE_NAME

# MCP Service URLs (will be updated when services are deployed)
MCP_ECHO_PING_URL=https://echo-ping.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_CUSTOMER_QUERY_URL=https://customer-query.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_DESTINATION_RECOMMENDATION_URL=https://destination-recommendation.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_ITINERARY_PLANNING_URL=https://itinerary-planning.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_WEB_SEARCH_URL=https://web-search.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_MODEL_INFERENCE_URL=https://model-inference.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_CODE_EVALUATION_URL=https://code-evaluation.internal.$CAE_NAME.eastus2.azurecontainerapps.io

# Access Tokens (replace with proper token management)
MCP_ECHO_PING_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
EOF

echo "✅ Configuration file created: .env.azure"

# Display summary
echo ""
echo "🎉 Azure Infrastructure Deployment Complete!"
echo ""
echo "📊 Resource Summary:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Azure OpenAI: $OPENAI_NAME"
echo "  Container Registry: $ACR_NAME"
echo "  Log Analytics: $LOG_WORKSPACE_NAME"
echo "  Application Insights: $APP_INSIGHTS_NAME"
echo "  Container Apps Environment: $CAE_NAME"
echo "  API Managed Identity: $API_IDENTITY_NAME"
echo "  UI Managed Identity: $UI_IDENTITY_NAME"
echo ""
echo "🔗 Next Steps:"
echo "  1. Review the .env.azure file"
echo "  2. Update your local .env files with the Azure configuration"
echo "  3. Deploy your container applications"
echo "  4. Run the teardown script when done to avoid costs"
echo ""
echo "💰 Cost Management:"
echo "  Run './scripts/teardown-infrastructure.sh' to remove all resources"
echo "  Monitor costs in Azure Portal: https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBlade" 