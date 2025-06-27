# Azure Infrastructure Scripts

This directory contains scripts for managing Azure infrastructure for the Azure AI Travel Agents project.

## 📋 Scripts Overview

### 🚀 `deploy-infrastructure.sh`
Creates all necessary Azure resources for the project.

**What it creates:**
- Resource Group (`rg-azure-ai-travel-agents-dev`)
- Azure OpenAI Service with GPT-4o-mini deployment
- Azure Container Registry
- Log Analytics Workspace
- Application Insights
- Container Apps Environment
- User-Assigned Managed Identities
- Role assignments for secure access

**Usage:**
```bash
./scripts/deploy-infrastructure.sh
```

### 🗑️ `teardown-infrastructure.sh`
Removes all Azure resources to avoid costs.

**What it removes:**
- Entire resource group and all contained resources
- All data stored in the resources (permanent)

**Usage:**
```bash
./scripts/teardown-infrastructure.sh
```

### 🔧 `configure-environment.sh`
Manages environment configuration and creates `.env` files.

**What it creates:**
- `.env` (development environment)
- `.env.dev` (development environment)
- `.env.prod` (production environment)
- `.env.local` (local overrides)
- Updates `.gitignore` and `.cursorignore`

**Usage:**
```bash
./scripts/configure-environment.sh
```

## 🏗️ Infrastructure Architecture

### Resource Naming Convention
Based on Azure standard abbreviations from `infra/abbreviations.json`:

| Resource Type | Abbreviation | Example |
|---------------|--------------|---------|
| Resource Group | `rg-` | `rg-azure-ai-travel-agents-dev` |
| Cognitive Services | `cog-` | `cog-12345678` |
| Container Registry | `cr` | `crazureaitravelagents12345678` |
| Container Apps Environment | `cae-` | `cae-azure-ai-travel-agents-12345678` |
| Managed Identity | `id-` | `id-api-azure-ai-travel-agents-12345678` |
| Log Analytics | `log-` | `log-azure-ai-travel-agents-12345678` |
| Application Insights | `appi-` | `appi-azure-ai-travel-agents-12345678` |

### Resource Tags
All resources are tagged with:
- `Project=azure-ai-travel-agents`
- `Environment=dev`
- `ResourceType=AI-Travel-Agents`
- `ManagedBy=Azure-CLI`
- `Owner=Development`
- `CostCenter=AI-Development`
- `DeploymentDate=YYYY-MM-DD`

## 🔐 Security & Access Management

### Managed Identities
- **API Identity**: Access to Azure OpenAI and Container Registry
- **UI Identity**: Access to Container Registry

### Role Assignments
- API Identity: `Cognitive Services OpenAI User`, `AcrPull`
- UI Identity: `AcrPull`

### Environment Variables
All sensitive configuration is managed through environment variables:
- Azure OpenAI endpoints and keys
- Container Registry credentials
- Application Insights connection strings
- MCP service access tokens

## 📁 Environment Files

### `.env` (Development)
Main development environment configuration.

### `.env.dev` (Development)
Alternative development environment configuration.

### `.env.prod` (Production)
Production environment configuration with:
- Production-specific settings
- Higher security requirements
- Performance optimizations

### `.env.local` (Local Overrides)
Local development overrides for:
- Local service URLs
- Development-specific settings
- Debug configurations

## 🚀 Quick Start

1. **Authenticate with Azure:**
   ```bash
   az login
   ```

2. **Deploy Infrastructure:**
   ```bash
   ./scripts/deploy-infrastructure.sh
   ```

3. **Configure Environment:**
   ```bash
   ./scripts/configure-environment.sh
   ```

4. **Deploy Applications:**
   ```bash
   # Deploy MCP services
   docker-compose -f src/docker-compose.yml up --build -d
   
   # Deploy API and UI
   # (Follow application-specific deployment instructions)
   ```

5. **Clean Up (when done):**
   ```bash
   ./scripts/teardown-infrastructure.sh
   ```

## 💰 Cost Management

### Estimated Monthly Costs (US East 2)
- **Azure OpenAI**: ~$50-200/month (depending on usage)
- **Container Registry**: ~$5/month
- **Log Analytics**: ~$2-10/month
- **Application Insights**: ~$2-10/month
- **Container Apps Environment**: ~$10-50/month
- **Managed Identities**: Free

**Total**: ~$70-280/month

### Cost Optimization Tips
1. **Use the teardown script** when not actively developing
2. **Monitor usage** in Azure Portal
3. **Set up budget alerts** in Azure Cost Management
4. **Use Basic SKU** for Container Registry
5. **Scale down** Container Apps when not in use

## 🔍 Monitoring & Troubleshooting

### Azure Portal Links
- **Resource Group**: `https://portal.azure.com/#@/resource/subscriptions/{subscription-id}/resourceGroups/rg-azure-ai-travel-agents-dev`
- **Cost Management**: `https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBlade`
- **Application Insights**: Available in the resource group

### Common Issues

#### Authentication Errors
```bash
# Re-authenticate with Azure
az login
az account set --subscription <subscription-id>
```

#### Resource Group Not Found
```bash
# Check if resource group exists
az group show --name rg-azure-ai-travel-agents-dev

# If not found, deploy infrastructure first
./scripts/deploy-infrastructure.sh
```

#### Permission Errors
```bash
# Check your role assignments
az role assignment list --assignee <your-principal-id>

# Ensure you have Contributor or Owner role on the subscription
```

## 📚 Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure OpenAI Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/)
- [Azure Managed Identities Documentation](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)

## 🤝 Contributing

When adding new Azure resources:
1. Update the deployment script with proper naming conventions
2. Add appropriate tags
3. Update the teardown script if needed
4. Update this README with new resource information
5. Test the scripts in a development environment first 