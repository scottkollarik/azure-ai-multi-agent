#!/bin/bash

# Azure AI Travel Agents Environment Configuration Script
# This script manages environment configuration and .env files

set -e  # Exit on any error

# Configuration
PROJECT_NAME="azure-ai-travel-agents"
ENVIRONMENT_NAME="dev"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Azure AI Travel Agents Environment Configuration${NC}"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT_NAME"
echo ""

# Function to check if Azure CLI is authenticated
check_azure_auth() {
    if ! az account show &> /dev/null; then
        echo -e "${RED}❌ Not authenticated with Azure. Please run 'az login' first.${NC}"
        exit 1
    fi
}

# Function to check if resource group exists
check_resource_group() {
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        echo -e "${RED}❌ Resource group '$RESOURCE_GROUP_NAME' does not exist.${NC}"
        echo "   Please run './scripts/deploy-infrastructure.sh' first."
        exit 1
    fi
}

# Function to create .env file from Azure configuration
create_env_file() {
    local env_file="$1"
    local env_name="$2"
    
    echo -e "${BLUE}📝 Creating $env_file for $env_name environment...${NC}"
    
    # Get Azure resource values
    OPENAI_NAME=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
    OPENAI_ENDPOINT=$(az cognitiveservices account show --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query properties.endpoint -o tsv)
    ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
    ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query loginServer -o tsv)
    APP_INSIGHTS_NAME=$(az monitor app-insights component list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
    APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query connectionString -o tsv)
    API_IDENTITY_NAME=$(az identity list --resource-group "$RESOURCE_GROUP_NAME" --query "[?contains(name, 'api')].name" -o tsv)
    API_CLIENT_ID=$(az identity show --name "$API_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)
    CAE_NAME=$(az containerapp env list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
    
    # Create .env file
    cat > "$env_file" << EOF
# Azure AI Travel Agents - $env_name Environment
# Generated on $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# Environment
NODE_ENV=$env_name
ENVIRONMENT_NAME=$env_name

# Azure Infrastructure
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP_NAME
AZURE_LOCATION=eastus2

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini
AZURE_OPENAI_API_VERSION=2024-07-18
LLM_PROVIDER=azure-openai

# Container Registry
AZURE_CONTAINER_REGISTRY_ENDPOINT=$ACR_LOGIN_SERVER

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING

# Managed Identities
AZURE_CLIENT_ID=$API_CLIENT_ID

# Container Apps Environment
AZURE_CONTAINER_APPS_ENVIRONMENT=$CAE_NAME

# MCP Service URLs
MCP_ECHO_PING_URL=https://echo-ping.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_CUSTOMER_QUERY_URL=https://customer-query.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_DESTINATION_RECOMMENDATION_URL=https://destination-recommendation.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_ITINERARY_PLANNING_URL=https://itinerary-planning.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_WEB_SEARCH_URL=https://web-search.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_MODEL_INFERENCE_URL=https://model-inference.internal.$CAE_NAME.eastus2.azurecontainerapps.io
MCP_CODE_EVALUATION_URL=https://code-evaluation.internal.$CAE_NAME.eastus2.azurecontainerapps.io

# Access Tokens (replace with proper token management)
MCP_ECHO_PING_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_CUSTOMER_QUERY_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_DESTINATION_RECOMMENDATION_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_ITINERARY_PLANNING_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_WEB_SEARCH_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_MODEL_INFERENCE_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider
MCP_CODE_EVALUATION_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider

# API Configuration
API_PORT=4000
API_HOST=0.0.0.0

# UI Configuration
UI_PORT=4200
UI_HOST=0.0.0.0

# Development Settings
DEBUG=true
LOG_LEVEL=debug
EOF

    echo -e "${GREEN}✅ Created $env_file${NC}"
}

# Function to update .gitignore and .cursorignore
update_ignore_files() {
    echo -e "${BLUE}📝 Updating .gitignore and .cursorignore...${NC}"
    
    # Update .gitignore
    if [ ! -f .gitignore ]; then
        echo "# Environment files" > .gitignore
        echo ".env*" >> .gitignore
    else
        if ! grep -q "\.env\*" .gitignore; then
            echo "" >> .gitignore
            echo "# Environment files" >> .gitignore
            echo ".env*" >> .gitignore
        fi
    fi
    
    # Update .cursorignore
    if [ ! -f .cursorignore ]; then
        echo "# Environment files" > .cursorignore
        echo ".env*" >> .cursorignore
    else
        if ! grep -q "\.env\*" .cursorignore; then
            echo "" >> .cursorignore
            echo "# Environment files" >> .cursorignore
            echo ".env*" >> .cursorignore
        fi
    fi
    
    echo -e "${GREEN}✅ Updated .gitignore and .cursorignore${NC}"
}

# Main script logic
main() {
    # Check Azure authentication
    check_azure_auth
    
    # Check if resource group exists
    check_resource_group
    
    # Update ignore files
    update_ignore_files
    
    # Create environment files
    echo -e "${BLUE}🔧 Creating environment configuration files...${NC}"
    
    # Create .env (default)
    create_env_file ".env" "development"
    
    # Create .env.dev
    create_env_file ".env.dev" "development"
    
    # Create .env.prod (with production settings)
    create_env_file ".env.prod" "production"
    
    # Create .env.local (for local overrides)
    if [ ! -f .env.local ]; then
        echo -e "${YELLOW}📝 Creating .env.local for local overrides...${NC}"
        cat > .env.local << EOF
# Local Development Overrides
# This file is for local development settings that override the main .env file
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# Local API URL (if running locally)
# API_BASE_URL=http://localhost:4000

# Local UI URL (if running locally)
# UI_BASE_URL=http://localhost:4200

# Local MCP Service URLs (if running locally)
# MCP_ECHO_PING_URL=http://localhost:8081
# MCP_CUSTOMER_QUERY_URL=http://localhost:8082
# MCP_DESTINATION_RECOMMENDATION_URL=http://localhost:8083
# MCP_ITINERARY_PLANNING_URL=http://localhost:8084
# MCP_WEB_SEARCH_URL=http://localhost:8085
# MCP_MODEL_INFERENCE_URL=http://localhost:8086
# MCP_CODE_EVALUATION_URL=http://localhost:8087

# Local development settings
DEBUG=true
LOG_LEVEL=debug
EOF
        echo -e "${GREEN}✅ Created .env.local${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Environment configuration complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Created files:${NC}"
    echo "  - .env (development environment)"
    echo "  - .env.dev (development environment)"
    echo "  - .env.prod (production environment)"
    echo "  - .env.local (local overrides)"
    echo ""
    echo -e "${BLUE}🔒 Security:${NC}"
    echo "  - All .env* files are now ignored by git and cursor"
    echo "  - Replace access tokens with proper token management"
    echo ""
    echo -e "${BLUE}📖 Usage:${NC}"
    echo "  - Use .env for local development"
    echo "  - Use .env.prod for production deployments"
    echo "  - Use .env.local for local overrides"
    echo ""
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo "  - Review and update access tokens in the .env files"
    echo "  - Never commit .env files to version control"
    echo "  - Use Azure Key Vault for production secrets"
}

# Run main function
main 