#!/bin/bash

# Travel Agent - Agent-Specific Deployment Script
# This script deploys the travel agent to its own resource group

set -e

# Configuration
AGENT_NAME="travel-agent"
PROJECT_NAME="azure-ai-multi-agent"
ENVIRONMENT_NAME="dev"
LOCATION="eastus2"
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
    echo "  --tools-only   Deploy only the tools, not the agent UI/API"
    echo "  --help         Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0"
    echo "  $0 --tools-only"
}

# Parse command line arguments
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
            echo -e "${RED}❌ Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 Starting Travel Agent Deployment${NC}"
echo "Agent: $AGENT_NAME"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Tools Only: $TOOLS_ONLY"
echo ""

# Check Azure CLI authentication
echo -e "${BLUE}🔐 Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Create resource group if it doesn't exist
echo -e "${BLUE}📦 Creating resource group...${NC}"
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=ResourceGroup"
    echo -e "${GREEN}✅ Resource group created: $RESOURCE_GROUP_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Resource group already exists: $RESOURCE_GROUP_NAME${NC}"
fi

# Create Container Registry
echo -e "${BLUE}📦 Creating Container Registry...${NC}"
ACR_NAME="acr${AGENT_NAME}${ENVIRONMENT_NAME}"
if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku Basic \
        --admin-enabled true \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=ContainerRegistry"
    echo -e "${GREEN}✅ Container Registry created: $ACR_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Container Registry already exists: $ACR_NAME${NC}"
fi

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query loginServer -o tsv)

# Create Container Apps Environment
echo -e "${BLUE}📦 Creating Container Apps Environment...${NC}"
CAE_NAME="cae-${AGENT_NAME}-${ENVIRONMENT_NAME}"
if ! az containerapp env show --name "$CAE_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    az containerapp env create \
        --name "$CAE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=ContainerAppsEnvironment"
    echo -e "${GREEN}✅ Container Apps Environment created: $CAE_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Container Apps Environment already exists: $CAE_NAME${NC}"
fi

# Create managed identity for the agent
echo -e "${BLUE}🔐 Creating managed identity...${NC}"
IDENTITY_NAME="id-${AGENT_NAME}-${ENVIRONMENT_NAME}"
if ! az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    az identity create \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=ManagedIdentity"
    echo -e "${GREEN}✅ Managed Identity created: $IDENTITY_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Managed Identity already exists: $IDENTITY_NAME${NC}"
fi

IDENTITY_CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query clientId -o tsv)

# Deploy travel agent specific tools
echo -e "${BLUE}🛠️  Deploying travel agent tools...${NC}"

# Travel agent specific tools
TRAVEL_TOOLS=("customer-query" "destination-recommendation" "itinerary-planning")

for tool in "${TRAVEL_TOOLS[@]}"; do
    echo "Deploying tool: $tool"
    
    # Check if tool exists in travel agent tools directory
    if [[ ! -d "agents/travel-agent/tools/$tool" ]]; then
        echo -e "${YELLOW}⚠️  Tool '$tool' not found in agents/travel-agent/tools/, checking shared tools...${NC}"
        if [[ ! -d "tools/shared/$tool" ]]; then
            echo -e "${RED}❌ Tool '$tool' not found anywhere, skipping...${NC}"
            continue
        fi
        TOOL_PATH="tools/shared/$tool"
    else
        TOOL_PATH="agents/travel-agent/tools/$tool"
    fi
    
    # Build and push tool image
    echo "Building tool image: $tool"
    docker build -t "$ACR_LOGIN_SERVER/$tool:latest" "$TOOL_PATH"
    docker push "$ACR_LOGIN_SERVER/$tool:latest"
    
    # Deploy as Container App
    CONTAINER_APP_NAME="tool-$tool"
    if ! az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
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
    else
        echo -e "${YELLOW}⚠️  Tool '$tool' already exists, updating...${NC}"
        az containerapp update \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --image "$ACR_LOGIN_SERVER/$tool:latest"
    fi
done

# Deploy agent API and UI if not tools-only
if [[ "$TOOLS_ONLY" == "false" ]]; then
    echo -e "${BLUE}🌐 Deploying agent API and UI...${NC}"
    
    # Deploy API
    if [[ -d "agents/travel-agent/api" ]]; then
        echo "Building and deploying API..."
        docker build -t "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest" "agents/travel-agent/api"
        docker push "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest"
        
        API_APP_NAME="${AGENT_NAME}-api"
        if ! az containerapp show --name "$API_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
            az containerapp create \
                --name "$API_APP_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --environment "$CAE_NAME" \
                --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest" \
                --target-port 4000 \
                --ingress external \
                --registry-server "$ACR_LOGIN_SERVER" \
                --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
                --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
                --env-vars "AGENT_NAME=$AGENT_NAME" "ENVIRONMENT=$ENVIRONMENT_NAME" \
                --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=API"
            
            echo -e "${GREEN}✅ API deployed${NC}"
        else
            echo -e "${YELLOW}⚠️  API already exists, updating...${NC}"
            az containerapp update \
                --name "$API_APP_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-api:latest"
        fi
    fi
    
    # Deploy UI
    if [[ -d "agents/travel-agent/ui" ]]; then
        echo "Building and deploying UI..."
        docker build -t "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest" "agents/travel-agent/ui"
        docker push "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest"
        
        UI_APP_NAME="${AGENT_NAME}-ui"
        if ! az containerapp show --name "$UI_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
            az containerapp create \
                --name "$UI_APP_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --environment "$CAE_NAME" \
                --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest" \
                --target-port 4200 \
                --ingress external \
                --registry-server "$ACR_LOGIN_SERVER" \
                --registry-username "$(az acr credential show --name $ACR_NAME --query username -o tsv)" \
                --registry-password "$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)" \
                --env-vars "AGENT_NAME=$AGENT_NAME" "ENVIRONMENT=$ENVIRONMENT_NAME" \
                --tags "Project=$PROJECT_NAME" "Environment=$ENVIRONMENT_NAME" "Agent=$AGENT_NAME" "Component=UI"
            
            echo -e "${GREEN}✅ UI deployed${NC}"
        else
            echo -e "${YELLOW}⚠️  UI already exists, updating...${NC}"
            az containerapp update \
                --name "$UI_APP_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --image "$ACR_LOGIN_SERVER/${AGENT_NAME}-ui:latest"
        fi
    fi
fi

# Generate environment file
echo -e "${BLUE}📝 Generating environment configuration...${NC}"
ENV_FILE=".env.${AGENT_NAME}"
cat > "$ENV_FILE" << EOF
# Travel Agent Environment Configuration
# Generated on $(date)

# Agent Configuration
AGENT_NAME=$AGENT_NAME
ENVIRONMENT_NAME=$ENVIRONMENT_NAME
RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME

# Azure Resources
AZURE_LOCATION=$LOCATION
AZURE_CONTAINER_REGISTRY_ENDPOINT=$ACR_LOGIN_SERVER
AZURE_CONTAINER_APPS_ENVIRONMENT=$CAE_NAME
AZURE_CLIENT_ID=$IDENTITY_CLIENT_ID

# Tool URLs (internal)
MCP_CUSTOMER_QUERY_URL=https://tool-customer-query.internal.$CAE_NAME.$LOCATION.azurecontainerapps.io
MCP_DESTINATION_RECOMMENDATION_URL=https://tool-destination-recommendation.internal.$CAE_NAME.$LOCATION.azurecontainerapps.io
MCP_ITINERARY_PLANNING_URL=https://tool-itinerary-planning.internal.$CAE_NAME.$LOCATION.azurecontainerapps.io

# API and UI URLs (external)
API_URL=https://$AGENT_NAME-api.$CAE_NAME.$LOCATION.azurecontainerapps.io
UI_URL=https://$AGENT_NAME-ui.$CAE_NAME.$LOCATION.azurecontainerapps.io
EOF

echo -e "${GREEN}✅ Environment file generated: $ENV_FILE${NC}"

echo -e "${GREEN}🎉 Travel Agent deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Container Registry: $ACR_NAME"
echo "  Container Apps Environment: $CAE_NAME"
echo "  Managed Identity: $IDENTITY_NAME"
echo "  Tools Deployed: ${TRAVEL_TOOLS[*]}"
if [[ "$TOOLS_ONLY" == "false" ]]; then
    echo "  API: ${AGENT_NAME}-api"
    echo "  UI: ${AGENT_NAME}-ui"
fi
echo ""
echo -e "${BLUE}🔗 URLs:${NC}"
echo "  UI: https://$AGENT_NAME-ui.$CAE_NAME.$LOCATION.azurecontainerapps.io"
echo "  API: https://$AGENT_NAME-api.$CAE_NAME.$LOCATION.azurecontainerapps.io"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. Configure Azure OpenAI or other LLM provider"
echo "  2. Set up monitoring and logging"
echo "  3. Test the agent functionality"
echo "  4. Configure custom domain if needed" 