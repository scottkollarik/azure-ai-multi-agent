#!/bin/bash

# Script to move conceptual content to Ideas folder
# Run this from your Mac terminal (not the container)

# Default path - update this to match your actual Ideas folder location
IDEAS_DIR="$HOME/Documents/GitHub/Ideas"

# Check if the Ideas directory exists
if [ ! -d "$IDEAS_DIR" ]; then
    echo "❌ Ideas directory not found at: $IDEAS_DIR"
    echo ""
    echo "Please update the IDEAS_DIR variable in this script to point to your actual Ideas folder location."
    echo "Common locations might be:"
    echo "  - \$HOME/Documents/Ideas"
    echo "  - \$HOME/Ideas" 
    echo "  - \$HOME/Documents/GitHub/Ideas"
    echo "  - \$HOME/Desktop/Ideas"
    echo ""
    echo "Or create the directory first:"
    echo "  mkdir -p \$HOME/Documents/GitHub/Ideas"
    exit 1
fi

PROJECT_DIR="/workspaces/azure-ai-travel-agents"

echo "Moving conceptual content to Ideas folder..."
echo "Source: $PROJECT_DIR/docs/concepts/"
echo "Destination: $IDEAS_DIR/azure-ai-travel-agents-concepts/"

# Create the destination directory
mkdir -p "$IDEAS_DIR/azure-ai-travel-agents-concepts"

# Copy the conceptual content
cp -r "$PROJECT_DIR/docs/concepts/"* "$IDEAS_DIR/azure-ai-travel-agents-concepts/"

# Create a README for the Ideas folder
cat > "$IDEAS_DIR/azure-ai-travel-agents-concepts/README.md" << 'EOF'
# Azure AI Travel Agents - Conceptual Ideas

This folder contains conceptual documents, whitepapers, and innovative ideas from the Azure AI Travel Agents project.

## Contents

- **Context Window Shifting Automation** - Novel approach to maintaining project continuity across AI chat sessions
- **Weird-Media Chaos Agent Vision** - Creative technology concepts for AI-generated art and media

## Connection to Project

These concepts originated from development work on the Azure AI Travel Agents project but represent broader innovative thinking that could apply to multiple projects.

## Usage

- **Reference material** for future development
- **Inspiration** for new features and approaches  
- **Documentation** of innovative thinking
- **Foundation** for grant applications and pitches
EOF

echo ""
echo "✅ Conceptual content moved to: $IDEAS_DIR/azure-ai-travel-agents-concepts/"
echo "📁 You can now organize these ideas alongside your other innovative concepts"
echo ""
echo "Next steps:"
echo "1. Review the content in your Ideas folder"
echo "2. Organize it with your other conceptual work"
echo "3. Consider how these ideas might apply to other projects" 