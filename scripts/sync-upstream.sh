#!/bin/bash

# Sync upstream changes while preserving local modifications
# This script helps maintain sync with the original Azure-Samples repo

set -e

echo "🔄 Syncing with upstream repository..."

# Fetch latest changes from upstream
echo "📥 Fetching latest changes from upstream..."
git fetch upstream

# Check if we're behind upstream
UPSTREAM_COMMITS=$(git rev-list HEAD..upstream/main --count)
if [ "$UPSTREAM_COMMITS" -eq 0 ]; then
    echo "✅ Already up to date with upstream"
    exit 0
fi

echo "📊 Found $UPSTREAM_COMMITS new commits from upstream"

# Create a backup branch of current state
BACKUP_BRANCH="backup-$(date +%Y%m%d-%H%M%S)"
echo "💾 Creating backup branch: $BACKUP_BRANCH"
git checkout -b "$BACKUP_BRANCH"

# Switch back to main
git checkout main

# Merge upstream changes
echo "🔄 Merging upstream changes..."
if git merge upstream/main --no-edit; then
    echo "✅ Successfully merged upstream changes"
else
    echo "⚠️  Merge conflicts detected. Resolving..."
    
    # List conflicted files
    echo "📋 Conflicted files:"
    git status --porcelain | grep "^UU"
    
    echo "🔧 Please resolve conflicts manually, then:"
    echo "   git add ."
    echo "   git commit"
    echo "   git push origin main"
    exit 1
fi

# Push to your fork
echo "📤 Pushing to your fork..."
git push origin main

echo "✅ Sync complete!"
echo "📝 Backup branch created: $BACKUP_BRANCH"
echo "💡 To clean up backup branch later: git branch -d $BACKUP_BRANCH" 