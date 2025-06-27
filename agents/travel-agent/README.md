# Travel Agent

The Travel Agent is a specialized AI agent within the Multi-Agent Framework designed to handle travel planning and booking requests. It leverages multiple MCP tools to provide comprehensive travel assistance.

## 🎯 Capabilities

- **Customer Query Understanding**: Extract travel preferences and intent from natural language
- **Destination Recommendation**: Suggest travel destinations based on preferences
- **Itinerary Planning**: Create detailed travel itineraries and plans
- **Travel Booking Assistance**: Help with booking recommendations and information

## 🛠️ Required Tools

| Tool | Purpose | Priority |
|------|---------|----------|
| `customer-query` | Extract travel preferences and intent | High |
| `destination-recommendation` | Recommend travel destinations | High |
| `itinerary-planning` | Create detailed itineraries | High |
| `echo-ping` | Testing and validation | Low |

## 🎛️ Optional Tools

| Tool | Purpose | Priority |
|------|---------|----------|
| `web-search` | Live travel information and prices | Medium |
| `code-evaluation` | Custom travel planning logic | Low |
| `model-inference` | Local AI processing | Low |

## 🚀 Deployment

### Prerequisites
1. Base infrastructure deployed: `./shared/infrastructure/deploy-base.sh`
2. Azure CLI authenticated: `az login`

### Deploy Travel Agent
```bash
# Deploy full travel agent (tools + UI/API)
./shared/infrastructure/deploy-agent.sh travel-agent

# Deploy only tools (for development)
./shared/infrastructure/deploy-agent.sh travel-agent --tools-only
```

### Environment Configuration
The deployment creates `.env.travel-agent` with all necessary configuration.

## 🔧 Configuration

### Agent Configuration (`config/agent-config.json`)
- Agent metadata and capabilities
- Tool requirements and priorities
- Deployment settings

### Tool Mapping (`config/tool-mapping.json`)
- Detailed tool usage and integration
- Workflow definitions
- Tool-specific configurations

## 📋 Workflows

### Primary Workflow: Travel Planning
1. **Customer Query Understanding** → Extract preferences
2. **Destination Recommendation** → Suggest destinations
3. **Itinerary Planning** → Create detailed plan
4. **Web Search** → Get current information (optional)

### Fallback Workflow: Basic Query
1. **Customer Query Understanding** → Extract intent
2. **Echo Ping** → Basic response

## 🎨 Customization

### Adding New Capabilities
1. Update `config/agent-config.json` with new capabilities
2. Add required tools to the tools array
3. Update `config/tool-mapping.json` with tool usage
4. Deploy with updated configuration

### Modifying Prompts
Edit the prompts section in `config/agent-config.json`:
```json
{
  "prompts": {
    "system": "Your custom system prompt",
    "capabilities": "Your custom capabilities description",
    "examples": ["Example 1", "Example 2"]
  }
}
```

## 🔍 Monitoring

### Azure Portal
- **Container Apps**: Monitor tool and agent performance
- **Application Insights**: View telemetry and logs
- **Log Analytics**: Centralized logging

### Key Metrics
- Tool response times
- Agent conversation success rates
- Error rates and types
- Resource utilization

## 🧪 Testing

### Local Development
```bash
# Start tools locally
docker-compose -f src/docker-compose.yml up -d

# Start API locally
cd src/api && npm start

# Start UI locally  
cd src/ui && npm start
```

### Test Scenarios
1. **Basic Travel Query**: "I want to plan a trip to Paris"
2. **Complex Planning**: "Family vacation to Chicago with kids aged 8 and 11"
3. **Budget Planning**: "Beach vacation under $3000"
4. **Seasonal Planning**: "Ski trip in December"

## 🔐 Security

### Access Control
- Agent-specific managed identity
- Tool-level access tokens
- Environment-based configuration

### Data Protection
- No persistent storage of personal data
- Secure communication between tools
- Azure Key Vault integration for secrets

## 📈 Performance

### Optimization Tips
- Use required tools only for basic queries
- Enable optional tools for complex planning
- Monitor tool response times
- Scale Container Apps based on demand

### Cost Management
- Base cost: ~$70-150/month (shared infrastructure)
- Agent cost: ~$20-50/month (additional)
- Monitor usage in Azure Portal

## 🚨 Troubleshooting

### Common Issues

#### Tools Not Responding
```bash
# Check tool status
az containerapp list --resource-group rg-azure-ai-multi-agent-dev --query "[?contains(name, 'tool-')].{Name:name, Status:properties.runningStatus}"

# Restart specific tool
az containerapp restart --name tool-echo-ping --resource-group rg-azure-ai-multi-agent-dev
```

#### Agent Configuration Issues
```bash
# Validate configuration
jq . agents/travel-agent/config/agent-config.json

# Check environment variables
cat .env.travel-agent
```

#### Deployment Failures
```bash
# Check deployment logs
az containerapp logs show --name travel-agent-api --resource-group rg-azure-ai-multi-agent-dev

# Redeploy specific component
./shared/infrastructure/deploy-agent.sh travel-agent --tools-only
```

## 🔄 Updates and Maintenance

### Updating Tools
1. Modify tool code in `src/tools/`
2. Rebuild and redeploy: `./shared/infrastructure/deploy-agent.sh travel-agent`
3. Test functionality
4. Monitor performance

### Updating Agent Configuration
1. Edit configuration files
2. Redeploy agent: `./shared/infrastructure/deploy-agent.sh travel-agent`
3. Verify changes

### Framework Updates
1. Update shared infrastructure scripts
2. Test with existing agents
3. Deploy to staging environment
4. Roll out to production

## 📚 Resources

- [Multi-Agent Framework Documentation](../README.md)
- [MCP Tools Documentation](../../src/tools/README.md)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [LlamaIndex.TS Documentation](https://ts.llamaindex.ai/) 