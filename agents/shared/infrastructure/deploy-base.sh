#!/bin/bash

# Multi-Agent Framework - Base Infrastructure Deployment
# This script deploys the shared infrastructure that all agents use

set -e

# Configuration
PROJECT_NAME="azure-ai-multi-agent"
ENVIRONMENT_NAME="dev"
LOCATION="eastus2"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT_NAME}"

# Standard Azure resource abbreviations
ABBR_RG="rg-"
ABBR_COG="cog-"
ABBR_CR="cr"
ABBR_CAE="cae-"
ABBR_ID="id-"
ABBR_LOG="log-"
ABBR_APPI="appi-"

# Generate unique resource token
RESOURCE_TOKEN=$(az account show --query id -o tsv | cut -c1-8)

# Tags for all resources
TAGS=(
    "Project=${PROJECT_NAME}"
    "Environment=${ENVIRONMENT_NAME}"
    "ResourceType=Multi-Agent-Framework"
    "ManagedBy=Azure-CLI"
    "Owner=Development"
    "CostCenter=AI-Development"
    "DeploymentDate=$(date +%Y-%m-%d)"
    "Component=Base-Infrastructure"
)

# Convert tags array to Azure CLI format
TAGS_STRING=""
for tag in "${TAGS[@]}"; do
    TAGS_STRING="$TAGS_STRING $tag"
done

echo "🚀 Starting Multi-Agent Framework Base Infrastructure Deployment"
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

# Create Shared Managed Identity
echo "🔐 Creating Shared Managed Identity..."
SHARED_IDENTITY_NAME="${ABBR_ID}shared-${PROJECT_NAME}${RESOURCE_TOKEN}"
az identity create \
    --name "$SHARED_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags $TAGS_STRING

echo "✅ Shared Managed Identity created: $SHARED_IDENTITY_NAME"

# Assign roles to shared identity
echo "🔑 Assigning roles to shared identity..."
SHARED_PRINCIPAL_ID=$(az identity show --name "$SHARED_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query principalId -o tsv)

# Assign OpenAI User role
az role assignment create \
    --assignee "$SHARED_PRINCIPAL_ID" \
    --role "Cognitive Services OpenAI User" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.CognitiveServices/accounts/$OPENAI_NAME"

# Assign ACR Pull role
az role assignment create \
    --assignee "$SHARED_PRINCIPAL_ID" \
    --role "AcrPull" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"

echo "✅ Roles assigned to shared identity"

# Get outputs for environment configuration
echo "📋 Gathering configuration outputs..."
OPENAI_ENDPOINT=$(az cognitiveservices account show --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query properties.endpoint -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query loginServer -o tsv)
APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query connectionString -o tsv)
SHARED_CLIENT_ID=$(az identity show --name "$SHARED_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)

# Create base .env file
echo "📝 Creating base .env file..."
cat > .env.base << EOF
# Multi-Agent Framework - Base Infrastructure Configuration
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

# Shared Managed Identity
AZURE_SHARED_CLIENT_ID=$SHARED_CLIENT_ID

# Container Apps Environment
AZURE_CONTAINER_APPS_ENVIRONMENT=$CAE_NAME

# Framework Configuration
FRAMEWORK_VERSION=1.0.0
FRAMEWORK_PROJECT_NAME=$PROJECT_NAME
FRAMEWORK_ENVIRONMENT=$ENVIRONMENT_NAME
EOF

echo "✅ Base configuration file created: .env.base"

# Display summary
echo ""
echo "🎉 Base Infrastructure Deployment Complete!"
echo ""
echo "📊 Resource Summary:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Azure OpenAI: $OPENAI_NAME"
echo "  Container Registry: $ACR_NAME"
echo "  Log Analytics: $LOG_WORKSPACE_NAME"
echo "  Application Insights: $APP_INSIGHTS_NAME"
echo "  Container Apps Environment: $CAE_NAME"
echo "  Shared Managed Identity: $SHARED_IDENTITY_NAME"
echo ""
echo "🔗 Next Steps:"
echo "  1. Deploy shared tools: ./shared/infrastructure/deploy-tools.sh"
echo "  2. Deploy specific agents: ./shared/infrastructure/deploy-agent.sh <agent-name>"
echo "  3. Run teardown when done: ./scripts/teardown-infrastructure.sh"
echo ""
echo "💰 Cost Management:"
echo "  Base infrastructure costs: ~$70-150/month"
echo "  Additional costs per agent: ~$20-50/month"
echo "  Monitor costs in Azure Portal" 