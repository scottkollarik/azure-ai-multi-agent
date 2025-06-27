# Multi-Agent Framework Infrastructure

This directory contains the infrastructure scripts for the Azure AI Multi-Agent Framework, enabling scalable deployment of multiple AI agents with shared tools and resources.

## 🏗️ Architecture Overview

The framework follows a layered deployment approach:

```
┌─────────────────────────────────────────────────────────────┐
│                    Multi-Agent Framework                    │
├─────────────────────────────────────────────────────────────┤
│  Agent Layer: travel-agent, healthcare-agent, etc.         │
├─────────────────────────────────────────────────────────────┤
│  Tool Layer: echo-ping, customer-query, etc.               │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer: OpenAI, ACR, Container Apps, etc.   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Scripts Overview

### 🚀 `deploy-base.sh`
Deploys the shared infrastructure that all agents use.

**What it creates:**
- Resource Group (`rg-azure-ai-multi-agent-dev`)
- Azure OpenAI Service with GPT-4o-mini deployment
- Azure Container Registry
- Log Analytics Workspace
- Application Insights
- Container Apps Environment
- Shared Managed Identity

**Usage:**
```bash
./shared/infrastructure/deploy-base.sh
```

### 🎯 `deploy-agent.sh`
Deploys a specific agent with its required tools and configuration.

**What it creates:**
- Agent-specific managed identity
- Required MCP tools as Container Apps
- Optional MCP tools (if requested)
- Agent UI and API (if not tools-only)
- Agent-specific environment configuration

**Usage:**
```bash
# Deploy full agent
./shared/infrastructure/deploy-agent.sh travel-agent

# Deploy only tools
./shared/infrastructure/deploy-agent.sh travel-agent --tools-only

# Show help
./shared/infrastructure/deploy-agent.sh --help
```

## 🎯 Agent Configuration

### Agent Structure
```
agents/
├── travel-agent/
│   ├── config/
│   │   ├── agent-config.json      # Agent metadata and capabilities
│   │   └── tool-mapping.json      # Tool usage and workflows
│   ├── prompts/                   # Agent-specific prompts
│   ├── workflows/                 # Agent-specific workflows
│   └── README.md                  # Agent documentation
├── healthcare-agent/              # Future agent
└── finance-agent/                 # Future agent
```

### Agent Configuration Format
```json
{
  "agent": {
    "name": "travel-agent",
    "version": "1.0.0",
    "description": "AI Travel Agent for planning and booking",
    "domain": "travel",
    "capabilities": ["query_understanding", "recommendations"]
  },
  "tools": {
    "required": ["customer-query", "destination-recommendation"],
    "optional": ["web-search", "code-evaluation"]
  },
  "workflow": {
    "primary": "travel_planning_workflow",
    "fallback": "basic_query_workflow"
  },
  "deployment": {
    "resource_group_suffix": "travel",
    "container_apps": ["travel-agent-api", "travel-agent-ui"]
  }
}
```

## 🛠️ Tool Management

### Tool Reusability
Tools are designed to be domain-agnostic and reusable across agents:

| Tool | Domain | Reusability |
|------|--------|-------------|
| `echo-ping` | Testing | Universal |
| `customer-query` | Query Understanding | Universal |
| `web-search` | Information Retrieval | Universal |
| `code-evaluation` | Custom Logic | Universal |
| `destination-recommendation` | Travel | Domain-specific |
| `itinerary-planning` | Travel | Domain-specific |

### Tool Deployment Strategy
1. **Required Tools**: Always deployed with the agent
2. **Optional Tools**: Deployed based on agent needs
3. **Shared Tools**: Can be used by multiple agents
4. **Domain-Specific Tools**: Tailored for specific domains

## 🔐 Security Architecture

### Identity Management
- **Shared Identity**: Access to base infrastructure
- **Agent Identity**: Agent-specific permissions
- **Tool Identity**: Tool-specific permissions (future)

### Access Control
```bash
# Shared Identity Roles
- Cognitive Services OpenAI User
- AcrPull

# Agent Identity Roles (per agent)
- Agent-specific permissions
- Tool access tokens
```

### Environment Variables
- Base configuration in `.env.base`
- Agent-specific configuration in `.env.{agent-name}`
- Tool-specific configuration in tool containers

## 💰 Cost Management

### Cost Structure
```
Base Infrastructure: ~$70-150/month
├── Azure OpenAI: ~$50-100/month
├── Container Registry: ~$5/month
├── Log Analytics: ~$2-10/month
├── Application Insights: ~$2-10/month
└── Container Apps Environment: ~$10-30/month

Per Agent: ~$20-50/month
├── Tool Container Apps: ~$10-30/month
├── Agent API/UI: ~$5-15/month
└── Additional resources: ~$5/month
```

### Cost Optimization
1. **Shared Infrastructure**: Base costs shared across all agents
2. **Tool Reuse**: Tools can be shared between agents
3. **Scaling**: Container Apps scale to zero when not in use
4. **Monitoring**: Track costs per agent and tool

## 🚀 Deployment Workflow

### 1. Initial Setup
```bash
# Deploy base infrastructure
./shared/infrastructure/deploy-base.sh

# Verify deployment
az group show --name rg-azure-ai-multi-agent-dev
```

### 2. Deploy First Agent
```bash
# Deploy travel agent
./shared/infrastructure/deploy-agent.sh travel-agent

# Verify agent deployment
az containerapp list --resource-group rg-azure-ai-multi-agent-dev
```

### 3. Deploy Additional Agents
```bash
# Deploy healthcare agent (when created)
./shared/infrastructure/deploy-agent.sh healthcare-agent

# Deploy finance agent (when created)
./shared/infrastructure/deploy-agent.sh finance-agent
```

### 4. Monitor and Scale
```bash
# Monitor costs
az consumption usage list --billing-period-name 202501

# Scale specific tools
az containerapp revision set-mode --name tool-echo-ping --resource-group rg-azure-ai-multi-agent-dev --mode Single
```

## 🔍 Monitoring and Observability

### Azure Monitor Integration
- **Application Insights**: Application telemetry
- **Log Analytics**: Centralized logging
- **Container Apps**: Built-in monitoring
- **Cost Management**: Resource cost tracking

### Key Metrics
- Tool response times
- Agent conversation success rates
- Resource utilization
- Cost per agent/tool
- Error rates and types

### Logging Strategy
```
Application Logs → Application Insights
Container Logs → Log Analytics
Infrastructure Logs → Azure Monitor
Cost Data → Cost Management
```

## 🧪 Testing Strategy

### Local Development
```bash
# Start tools locally
docker-compose -f src/docker-compose.yml up -d

# Test specific agent
./shared/infrastructure/deploy-agent.sh travel-agent --tools-only
```

### Integration Testing
1. Deploy base infrastructure
2. Deploy agent with tools
3. Test agent workflows
4. Verify tool integration
5. Monitor performance

### Load Testing
- Test tool scalability
- Monitor resource usage
- Validate cost predictions
- Performance optimization

## 🔄 Maintenance and Updates

### Infrastructure Updates
1. Update base infrastructure scripts
2. Test in development environment
3. Deploy to staging
4. Roll out to production

### Agent Updates
1. Update agent configuration
2. Redeploy specific agent
3. Test functionality
4. Monitor performance

### Tool Updates
1. Update tool code
2. Rebuild and redeploy
3. Test with all agents
4. Monitor for regressions

## 🚨 Troubleshooting

### Common Issues

#### Base Infrastructure Not Found
```bash
# Check if resource group exists
az group show --name rg-azure-ai-multi-agent-dev

# Redeploy if missing
./shared/infrastructure/deploy-base.sh
```

#### Agent Deployment Fails
```bash
# Check agent configuration
jq . agents/travel-agent/config/agent-config.json

# Validate tool mappings
jq . agents/travel-agent/config/tool-mapping.json

# Check deployment logs
az containerapp logs show --name travel-agent-api --resource-group rg-azure-ai-multi-agent-dev
```

#### Tools Not Responding
```bash
# Check tool status
az containerapp list --resource-group rg-azure-ai-multi-agent-dev --query "[?contains(name, 'tool-')].{Name:name, Status:properties.runningStatus}"

# Restart specific tool
az containerapp restart --name tool-echo-ping --resource-group rg-azure-ai-multi-agent-dev
```

### Debug Commands
```bash
# Check all resources
az resource list --resource-group rg-azure-ai-multi-agent-dev --output table

# Check Container Apps
az containerapp list --resource-group rg-azure-ai-multi-agent-dev --output table

# Check managed identities
az identity list --resource-group rg-azure-ai-multi-agent-dev --output table

# Check role assignments
az role assignment list --resource-group rg-azure-ai-multi-agent-dev --output table
```

## 📚 Resources

- [Multi-Agent Framework Documentation](../README.md)
- [Agent Development Guide](../agents/README.md)
- [MCP Tools Documentation](../../src/tools/README.md)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure Managed Identities Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

## 🤝 Contributing

When adding new agents or tools:
1. Follow the established configuration format
2. Update documentation
3. Test deployment scripts
4. Monitor costs and performance
5. Update this README with new information 