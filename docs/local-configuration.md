# Local Configuration Guide

## Minimum Configuration Baseline

To get the Azure AI Travel Agents working locally, you need to create a `.env` file in `src/api/` with the following essential configuration:

### Required Environment Variables

```bash
# LLM Provider Configuration
LLM_PROVIDER=docker-models

# Docker Model Configuration (for local development)
DOCKER_MODEL_ENDPOINT=http://localhost:12434/engines/llama.cpp/v1
DOCKER_MODEL=ai/phi4:14B-Q4_0

# MCP Tool URLs (local Docker containers)
MCP_CUSTOMER_QUERY_URL=http://localhost:5001
MCP_DESTINATION_RECOMMENDATION_URL=http://localhost:5002
MCP_ITINERARY_PLANNING_URL=http://localhost:5003
MCP_CODE_EVALUATION_URL=http://localhost:5004
MCP_MODEL_INFERENCE_URL=http://localhost:5005
MCP_WEB_SEARCH_URL=http://localhost:5006
MCP_ECHO_PING_URL=http://localhost:5007
MCP_ECHO_PING_ACCESS_TOKEN=123-this-is-a-fake-token-please-use-a-token-provider

# OpenTelemetry Configuration
OTEL_SERVICE_NAME=api
OTEL_EXPORTER_OTLP_ENDPOINT=http://aspire-dashboard:18889
OTEL_EXPORTER_OTLP_HEADERS=header-value

# Docker Environment Flag
IS_LOCAL_DOCKER_ENV=true
DEBUG=true
```

## Alternative LLM Providers

### Azure OpenAI (requires Azure subscription)
```bash
LLM_PROVIDER=azure-openai
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini
AZURE_OPENAI_API_KEY=your-api-key
```

### Ollama (local)
```bash
LLM_PROVIDER=ollama-models
OLLAMA_MODEL_ENDPOINT=http://localhost:11434
OLLAMA_MODEL=llama3.2
```

### Azure Foundry Local
```bash
LLM_PROVIDER=foundry-local
AZURE_FOUNDRY_LOCAL_MODEL_ALIAS=phi-4-mini-reasoning
```

## Prerequisites

1. **Docker Desktop v4.42.0+** with Model Runner enabled
2. **Docker model pulled**: `docker model pull ai/phi4:14B-Q4_0`
3. **Node.js** for API and UI services

## Quick Start

1. Create the `.env` file in `src/api/` with the configuration above
2. Run the preview script: `./preview.sh`
3. Access the UI at http://localhost:4200

## Troubleshooting

- Ensure Docker Model Runner is enabled: `docker desktop enable model-runner --tcp 12434`
- Verify the model is pulled: `docker model list`
- Check container health: `docker ps`
- View logs: `docker logs web-api` 