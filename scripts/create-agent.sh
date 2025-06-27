#!/bin/bash

# Multi-Agent Framework - Agent Creation Script
# This script creates a new agent from templates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <agent-name> [options]"
    echo ""
    echo "Arguments:"
    echo "  agent-name    Name of the agent to create (e.g., 'customer-service', 'sales-agent')"
    echo ""
    echo "Options:"
    echo "  -d, --domain <domain>        Domain of the agent (e.g., 'customer-service', 'sales')"
    echo "  -c, --capabilities <list>    Comma-separated list of capabilities"
    echo "  -t, --tools <list>           Comma-separated list of required tools"
    echo "  -w, --workflow <name>        Primary workflow name"
    echo "  -p, --prompt <prompt>        System prompt for the agent"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 customer-service -d customer-service -c 'query_understanding,issue_resolution'"
    echo "  $0 sales-agent -d sales -c 'lead_qualification,proposal_generation' -t 'customer-query,web-search'"
}

# Function to validate agent name
validate_agent_name() {
    local name=$1
    if [[ ! $name =~ ^[a-z0-9-]+$ ]]; then
        print_error "Agent name must contain only lowercase letters, numbers, and hyphens"
        exit 1
    fi
    
    if [[ -d "agents/$name" ]]; then
        print_error "Agent '$name' already exists"
        exit 1
    fi
}

# Function to create agent directory structure
create_agent_structure() {
    local agent_name=$1
    local agent_dir="agents/$agent_name"
    
    print_status "Creating agent directory structure for '$agent_name'"
    
    mkdir -p "$agent_dir/config"
    mkdir -p "$agent_dir/docs"
    mkdir -p "$agent_dir/tests"
    
    print_success "Created directory structure: $agent_dir"
}

# Function to generate agent configuration
generate_agent_config() {
    local agent_name=$1
    local domain=${2:-$agent_name}
    local capabilities=${3:-"basic_query_understanding"}
    local tools=${4:-"echo-ping"}
    local workflow=${5:-"basic_query_workflow"}
    local prompt=${6:-"You are an AI agent specialized in $domain. Help users with their queries."}
    
    local config_file="agents/$agent_name/config/agent-config.json"
    
    print_status "Generating agent configuration"
    
    # Convert comma-separated lists to JSON arrays
    local capabilities_array=$(echo "$capabilities" | tr ',' '\n' | jq -R . | jq -s .)
    local tools_array=$(echo "$tools" | tr ',' '\n' | jq -R . | jq -s .)
    
    # Create the configuration JSON
    cat > "$config_file" << EOF
{
  "agent": {
    "name": "$agent_name",
    "version": "1.0.0",
    "description": "AI Agent for $domain operations",
    "domain": "$domain",
    "capabilities": $capabilities_array,
    "inherits_from": "base-agent"
  },
  "tools": {
    "required": $tools_array,
    "optional": [
      "web-search",
      "code-evaluation",
      "model-inference"
    ]
  },
  "workflow": {
    "primary": "$workflow",
    "fallback": "basic_query_workflow"
  },
  "prompts": {
    "system": "$prompt",
    "capabilities": "I can help you with $domain related tasks and queries.",
    "examples": [
      "Example query 1",
      "Example query 2",
      "Example query 3"
    ]
  },
  "deployment": {
    "resource_group_suffix": "$agent_name",
    "container_apps": [
      "$agent_name-api",
      "$agent_name-ui"
    ],
    "environment_variables": {
      "AGENT_TYPE": "$agent_name",
      "AGENT_VERSION": "1.0.0"
    }
  },
  "llm_providers": {
    "azure_ai": {
      "enabled": true,
      "config": {
        "model": "gpt-4o-mini",
        "deployment": "gpt-4o-mini",
        "api_version": "2024-07-18"
      }
    },
    "ollama": {
      "enabled": false,
      "config": {
        "model": "llama3.2",
        "endpoint": "http://localhost:11434"
      }
    },
    "docker_models": {
      "enabled": false,
      "config": {
        "model": "ai/phi4:14B-Q4_0",
        "endpoint": "http://localhost:12434/engines/llama.cpp/v1"
      }
    }
  },
  "search_providers": {
    "bing": {
      "enabled": true,
      "rate_limit": "1000/hour"
    },
    "duckduckgo": {
      "enabled": false,
      "rate_limit": "100/hour"
    }
  }
}
EOF
    
    print_success "Generated agent configuration: $config_file"
}

# Function to generate tool mapping
generate_tool_mapping() {
    local agent_name=$1
    local tools=${2:-"echo-ping"}
    
    local mapping_file="agents/$agent_name/config/tool-mapping.json"
    
    print_status "Generating tool mapping"
    
    # Convert comma-separated tools to array
    local tools_array=$(echo "$tools" | tr ',' '\n' | jq -R . | jq -s .)
    
    # Create basic tool mapping
    cat > "$mapping_file" << EOF
{
  "tool_mappings": {
    "echo-ping": {
      "purpose": "testing_and_validation",
      "priority": "low",
      "usage": "Connectivity testing and basic validation",
      "required": false
    }
  },
  "workflow_integration": {
    "basic_query_workflow": [
      "echo-ping"
    ]
  }
}
EOF
    
    print_success "Generated tool mapping: $mapping_file"
}

# Function to generate README
generate_readme() {
    local agent_name=$1
    local domain=${2:-$agent_name}
    local capabilities=${3:-"basic_query_understanding"}
    
    local readme_file="agents/$agent_name/README.md"
    
    print_status "Generating README"
    
    cat > "$readme_file" << EOF
# $agent_name

The $agent_name is a specialized AI agent within the Multi-Agent Framework designed to handle $domain operations.

## 🎯 Capabilities

$(echo "$capabilities" | tr ',' '\n' | sed 's/^/- /')

## 🛠️ Required Tools

| Tool | Purpose | Priority |
|------|---------|----------|
| \`echo-ping\` | Testing and validation | Low |

## 🎛️ Optional Tools

| Tool | Purpose | Priority |
|------|---------|----------|
| \`web-search\` | Live information and data | Medium |
| \`code-evaluation\` | Custom logic execution | Low |
| \`model-inference\` | Local AI processing | Low |

## 🚀 Deployment

### Prerequisites
1. Base infrastructure deployed: \`./shared/infrastructure/deploy-base.sh\`
2. Azure CLI authenticated: \`az login\`

### Deploy Agent
\`\`\`bash
# Deploy full agent (tools + UI/API)
./shared/infrastructure/deploy-agent.sh $agent_name

# Deploy only tools (for development)
./shared/infrastructure/deploy-agent.sh $agent_name --tools-only
\`\`\`

## 🔧 Configuration

### Agent Configuration (\`config/agent-config.json\`)
- Agent metadata and capabilities
- Tool requirements and priorities
- Deployment settings

### Tool Mapping (\`config/tool-mapping.json\`)
- Detailed tool usage and integration
- Workflow definitions
- Tool-specific configurations

## 🧪 Testing

### Local Development
\`\`\`bash
# Start tools locally
docker-compose -f src/docker-compose.yml up -d

# Start API locally
cd src/api && npm start

# Start UI locally  
cd src/ui && npm start
\`\`\`

## 🔐 Security

### Access Control
- Agent-specific managed identity
- Tool-level access tokens
- Environment-based configuration

## 📈 Performance

### Cost Management
- Base cost: ~\$70-150/month (shared infrastructure)
- Agent cost: ~\$20-50/month (additional)
- Monitor usage in Azure Portal
EOF
    
    print_success "Generated README: $readme_file"
}

# Function to update agents registry
update_agents_registry() {
    local agent_name=$1
    local domain=${2:-$agent_name}
    
    local registry_file="shared/config/agents-registry.json"
    
    # Create registry file if it doesn't exist
    if [[ ! -f "$registry_file" ]]; then
        cat > "$registry_file" << EOF
{
  "agents": {},
  "metadata": {
    "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "version": "1.0.0"
  }
}
EOF
    fi
    
    # Add agent to registry
    local temp_file=$(mktemp)
    jq --arg name "$agent_name" \
       --arg domain "$domain" \
       --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.agents[$name] = {
         "name": $name,
         "domain": $domain,
         "created": $created,
         "status": "active",
         "config_path": "agents/\($name)/config/agent-config.json"
       } | .metadata.last_updated = now | .metadata.last_updated |= strftime("%Y-%m-%dT%H:%M:%SZ")' \
       "$registry_file" > "$temp_file"
    
    mv "$temp_file" "$registry_file"
    
    print_success "Updated agents registry: $registry_file"
}

# Main script logic
main() {
    # Parse command line arguments
    AGENT_NAME=""
    DOMAIN=""
    CAPABILITIES="basic_query_understanding"
    TOOLS="echo-ping"
    WORKFLOW="basic_query_workflow"
    PROMPT=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -c|--capabilities)
                CAPABILITIES="$2"
                shift 2
                ;;
            -t|--tools)
                TOOLS="$2"
                shift 2
                ;;
            -w|--workflow)
                WORKFLOW="$2"
                shift 2
                ;;
            -p|--prompt)
                PROMPT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$AGENT_NAME" ]]; then
                    AGENT_NAME="$1"
                else
                    print_error "Multiple agent names specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$AGENT_NAME" ]]; then
        print_error "Agent name is required"
        show_usage
        exit 1
    fi
    
    # Set default domain if not provided
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$AGENT_NAME"
    fi
    
    # Set default prompt if not provided
    if [[ -z "$PROMPT" ]]; then
        PROMPT="You are an AI agent specialized in $domain operations. Help users with their queries."
    fi
    
    # Validate agent name
    validate_agent_name "$AGENT_NAME"
    
    print_status "Creating agent: $AGENT_NAME"
    print_status "Domain: $DOMAIN"
    print_status "Capabilities: $CAPABILITIES"
    print_status "Tools: $TOOLS"
    print_status "Workflow: $WORKFLOW"
    
    # Create agent structure
    create_agent_structure "$AGENT_NAME"
    
    # Generate configuration files
    generate_agent_config "$AGENT_NAME" "$DOMAIN" "$CAPABILITIES" "$TOOLS" "$WORKFLOW" "$PROMPT"
    generate_tool_mapping "$AGENT_NAME" "$TOOLS"
    generate_readme "$AGENT_NAME" "$DOMAIN" "$CAPABILITIES"
    
    # Update agents registry
    update_agents_registry "$AGENT_NAME" "$DOMAIN"
    
    print_success "Agent '$AGENT_NAME' created successfully!"
    print_status "Next steps:"
    print_status "1. Review and customize the configuration in agents/$AGENT_NAME/config/"
    print_status "2. Add domain-specific tools to the tool mapping"
    print_status "3. Test the agent locally: ./scripts/test-agent.sh $AGENT_NAME"
    print_status "4. Deploy the agent: ./shared/infrastructure/deploy-agent.sh $AGENT_NAME"
}

# Run main function with all arguments
main "$@" 