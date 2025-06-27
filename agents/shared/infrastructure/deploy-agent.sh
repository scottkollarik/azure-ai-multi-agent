#!/bin/bash

# Multi-Agent Framework - Agent Deployment Script
# This script deploys a specific agent with its required tools and configuration

set -e

# Configuration
PROJECT_NAME="azure-ai-multi-agent"
ENVIRONMENT_NAME="dev"
LOCATION="eastus2"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 <agent-name> [options]"
    echo ""
    echo -e "${BLUE}Arguments:${NC}"
    echo "  agent-name    Name of the agent to deploy (e.g., travel-agent)"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --tools-only   Deploy only the tools, not the agent UI/API"
    echo "  --help         Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 travel-agent"
    echo "  $0 travel-agent --tools-only"
    echo ""
    echo -e "${BLUE}Available Agents:${NC}"
    echo "  travel-agent   - AI Travel Agent for planning and booking"
    echo "  (future agents will be added here)"
}

# Parse command line arguments
AGENT_NAME=""
TOOLS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --tools-only)
            TOOLS_ONLY=true
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
            if [[ -z "$AGENT_NAME" ]]; then
                AGENT_NAME="$1"
            else
                echo -e "${RED}❌ Multiple agent names specified${NC}"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate agent name
if [[ -z "$AGENT_NAME" ]]; then
    echo -e "${RED}❌ Agent name is required${NC}"
    usage
    exit 1
fi

# Check if agent exists
AGENT_CONFIG_PATH="agents/${AGENT_NAME}/config/agent-config.json"
if [[ ! -f "$AGENT_CONFIG_PATH" ]]; then
    echo -e "${RED}❌ Agent '$AGENT_NAME' not found${NC}"
    echo "Available agents:"
    for agent_dir in agents/*/; do
        if [[ -d "$agent_dir" ]]; then
            agent_name=$(basename "$agent_dir")
            echo "  - $agent_name"
        fi
    done
    exit 1
fi

echo -e "${BLUE}🚀 Starting Agent Deployment${NC}"
echo "Agent: $AGENT_NAME"
echo "Tools Only: $TOOLS_ONLY"
echo ""

# Check Azure CLI authentication
echo -e "${BLUE}🔐 Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Check if resource group exists
echo -e "${BLUE}🔍 Checking if base infrastructure exists...${NC}"
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo -e "${RED}❌ Resource group '$RESOURCE_GROUP_NAME' does not exist.${NC}"
    echo "Please run './shared/infrastructure/deploy-base.sh' first."
    exit 1
fi

# Load agent configuration
echo -e "${BLUE}📋 Loading agent configuration...${NC}"
AGENT_CONFIG=$(cat "$AGENT_CONFIG_PATH")
AGENT_DOMAIN=$(echo "$AGENT_CONFIG" | jq -r '.agent.domain')
AGENT_VERSION=$(echo "$AGENT_CONFIG" | jq -r '.agent.version')
REQUIRED_TOOLS=$(echo "$AGENT_CONFIG" | jq -r '.tools.required[]')
OPTIONAL_TOOLS=$(echo "$AGENT_CONFIG" | jq -r '.tools.optional[]')

echo "Agent Domain: $AGENT_DOMAIN"
echo "Agent Version: $AGENT_VERSION"
echo "Required Tools: $REQUIRED_TOOLS"
echo "Optional Tools: $OPTIONAL_TOOLS"

# Get base infrastructure values
echo -e "${BLUE}📋 Getting base infrastructure values...${NC}"
CAE_NAME=$(az containerapp env list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query loginServer -o tsv)
SHARED_IDENTITY_NAME=$(az identity list --resource-group "$RESOURCE_GROUP_NAME" --query "[?contains(name, 'shared')].name" -o tsv)
SHARED_CLIENT_ID=$(az identity show --name "$SHARED_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)

# Create agent-specific managed identity
echo -e "${BLUE}🔐 Creating agent-specific managed identity...${NC}"
AGENT_IDENTITY_NAME="id-${AGENT_NAME}-${PROJECT_NAME}"
az identity create \
    --name "$AGENT_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=Agent-Identity"

AGENT_CLIENT_ID=$(az identity show --name "$AGENT_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)

# Deploy required tools as Container Apps
echo -e "${BLUE}🛠️  Deploying required tools...${NC}"
for tool in $REQUIRED_TOOLS; do
    echo "Deploying tool: $tool"
    
    # Check if tool exists
    if [[ ! -d "src/tools/$tool" ]]; then
        echo -e "${YELLOW}⚠️  Tool '$tool' not found in src/tools/, skipping...${NC}"
        continue
    fi
    
    # Build and push tool image
    echo "Building tool image: $tool"
    docker build -t "$ACR_LOGIN_SERVER/$tool:latest" "src/tools/$tool"
    docker push "$ACR_LOGIN_SERVER/$tool:latest"
    
    # Deploy as Container App
    CONTAINER_APP_NAME="tool-$tool"
    az containerapp create \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --environment "$CAE_NAME" \
        --image "$ACR_LOGIN_SERVER/$tool:latest" \
        --target-port 8080 \
        --ingress external \
        --registry-server "$ACR_LOGIN_SERVER" \
        --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
        --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
        --env-vars "AGENT_NAME=$AGENT_NAME" "TOOL_NAME=$tool" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=Tool"
    
    echo -e "${GREEN}✅ Tool '$tool' deployed${NC}"
done

# Deploy optional tools if requested
if [[ "$TOOLS_ONLY" == "false" ]]; then
    echo -e "${BLUE}🛠️  Deploying optional tools...${NC}"
    for tool in $OPTIONAL_TOOLS; do
        echo "Deploying optional tool: $tool"
        
        if [[ ! -d "src/tools/$tool" ]]; then
            echo -e "${YELLOW}⚠️  Tool '$tool' not found, skipping...${NC}"
            continue
        fi
        
        # Build and push tool image
        docker build -t "$ACR_LOGIN_SERVER/$tool:latest" "src/tools/$tool"
        docker push "$ACR_LOGIN_SERVER/$tool:latest"
        
        # Deploy as Container App
        CONTAINER_APP_NAME="tool-$tool"
        az containerapp create \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --environment "$CAE_NAME" \
            --image "$ACR_LOGIN_SERVER/$tool:latest" \
            --target-port 8080 \
            --ingress external \
            --registry-server "$ACR_LOGIN_SERVER" \
            --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
            --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
            --env-vars "AGENT_NAME=$AGENT_NAME" "TOOL_NAME=$tool" \
            --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=Tool"
        
        echo -e "${GREEN}✅ Optional tool '$tool' deployed${NC}"
    done
fi

# Deploy agent UI and API if not tools-only
if [[ "$TOOLS_ONLY" == "false" ]]; then
    echo -e "${BLUE}🎯 Deploying agent UI and API...${NC}"
    
    # Deploy API
    echo "Deploying agent API..."
    docker build -t "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest" "src/api"
    docker push "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest"
    
    az containerapp create \
        --name "${AGENT_NAME}-api" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --environment "$CAE_NAME" \
        --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest" \
        --target-port 4000 \
        --ingress external \
        --registry-server "$ACR_LOGIN_SERVER" \
        --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
        --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
        --env-vars "AGENT_NAME=$AGENT_NAME" "AGENT_DOMAIN=$AGENT_DOMAIN" "AGENT_VERSION=$AGENT_VERSION" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=API"
    
    # Deploy UI
    echo "Deploying agent UI..."
    docker build -t "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest" "src/ui"
    docker push "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest"
    
    az containerapp create \
        --name "${AGENT_NAME}-ui" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --environment "$CAE_NAME" \
        --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest" \
        --target-port 4200 \
        --ingress external \
        --registry-server "$ACR_LOGIN_SERVER" \
        --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
        --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
        --env-vars "AGENT_NAME=$AGENT_NAME" "AGENT_DOMAIN=$AGENT_DOMAIN" "AGENT_VERSION=$AGENT_VERSION" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=UI"
    
    echo -e "${GREEN}✅ Agent UI and API deployed${NC}"
fi

# Create agent-specific environment file
echo -e "${BLUE}📝 Creating agent environment file...${NC}"
cat > ".env.${AGENT_NAME}" << EOF
# Agent: $AGENT_NAME
# Generated on $(date)

# Agent Configuration
AGENT_NAME=$AGENT_NAME
AGENT_DOMAIN=$AGENT_DOMAIN
AGENT_VERSION=$AGENT_VERSION

# Base Infrastructure (from .env.base)
$(cat .env.base)

# Agent-Specific Configuration
AGENT_CLIENT_ID=$AGENT_CLIENT_ID

# Tool URLs (will be updated with actual URLs)
$(for tool in $REQUIRED_TOOLS; do
    echo "MCP_$(echo $tool | tr '[:lower:]' '[:upper:]' | tr '-' '_')_URL=https://tool-$tool.internal.$CAE_NAME.eastus2.azurecontainerapps.io"
done)

$(for tool in $OPTIONAL_TOOLS; do
    echo "MCP_$(echo $tool | tr '[:lower:]' '[:upper:]' | tr '-' '_')_URL=https://tool-$tool.internal.$CAE_NAME.eastus2.azurecontainerapps.io"
done)

# Access Tokens (replace with proper token management)
$(for tool in $REQUIRED_TOOLS; do
    echo "MCP_$(echo $tool | tr '[:lower:]' '[:upper:]' | tr '-' '_')_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider"
done)

$(for tool in $OPTIONAL_TOOLS; do
    echo "MCP_$(echo $tool | tr '[:lower:]' '[:upper:]' | tr '-' '_')_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider"
done)
EOF

echo -e "${GREEN}✅ Agent environment file created: .env.${AGENT_NAME}${NC}"

# Display summary
echo ""
echo -e "${GREEN}🎉 Agent Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo "  Agent: $AGENT_NAME"
echo "  Domain: $AGENT_DOMAIN"
echo "  Version: $AGENT_VERSION"
echo "  Tools Only: $TOOLS_ONLY"
echo ""
echo -e "${BLUE}🔗 Access URLs:${NC}"
if [[ "$TOOLS_ONLY" == "false" ]]; then
    API_URL=$(az containerapp show --name "${AGENT_NAME}-api" --resource-group "$RESOURCE_GROUP_NAME" --query properties.configuration.ingress.fqdn -o tsv)
    UI_URL=$(az containerapp show --name "${AGENT_NAME}-ui" --resource-group "$RESOURCE_GROUP_NAME" --query properties.configuration.ingress.fqdn -o tsv)
    echo "  API: https://$API_URL"
    echo "  UI: https://$UI_URL"
fi
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "  1. Update access tokens in .env.${AGENT_NAME}"
echo "  2. Test the agent functionality"
echo "  3. Monitor in Azure Portal"
echo ""
echo -e "${BLUE}💰 Cost Impact:${NC}"
echo "  Additional cost: ~$20-50/month for this agent"
echo "  Monitor costs in Azure Portal" 