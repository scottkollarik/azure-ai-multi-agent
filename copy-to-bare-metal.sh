#!/bin/bash

# Script to copy Azure AI Travel Agents project to bare metal
# Excludes context_summaries to keep them private

SOURCE_DIR="/workspaces/azure-ai-travel-agents"
DEST_DIR="$HOME/azure-ai-travel-agents-bare-metal"

echo "Copying Azure AI Travel Agents to bare metal..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Excluding: context_summaries/"

# Create destination directory
mkdir -p "$DEST_DIR"

# Copy everything except context_summaries
rsync -av --exclude='context_summaries/' --exclude='.git/' "$SOURCE_DIR/" "$DEST_DIR/"

echo ""
echo "✅ Copy complete!"
echo "📁 Project copied to: $DEST_DIR"
echo "🔒 Context summaries kept private in container"
echo ""
echo "Next steps:"
echo "1. Close VS Code/Cursor"
echo "2. Open $DEST_DIR in VS Code/Cursor"
echo "3. Run: docker-compose -f src/docker-compose.yml up -d"
echo "4. Run: cd src/api && npm start"
echo "5. Run: cd src/ui && npm start" 