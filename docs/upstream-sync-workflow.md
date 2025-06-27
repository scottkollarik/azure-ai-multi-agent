# Upstream Sync Workflow

This document explains how to sync changes from the original Azure-Samples repository while preserving your local modifications for the multi-agent system.

## Repository Structure

```
origin  → https://github.com/scottkollarik/azure-ai-multi-agent.git (your fork)
upstream → https://github.com/Azure-Samples/azure-ai-travel-agents.git (original)
```

## Quick Sync

To sync with upstream changes:

```bash
# Run the automated sync script
./scripts/sync-upstream.sh
```

## Manual Sync Process

If you prefer manual control:

### 1. Fetch upstream changes
```bash
git fetch upstream
```

### 2. Check what's new
```bash
git log HEAD..upstream/main --oneline
```

### 3. Create backup branch (optional but recommended)
```bash
git checkout -b backup-$(date +%Y%m%d-%H%M%S)
git checkout main
```

### 4. Merge upstream changes
```bash
git merge upstream/main
```

### 5. Resolve conflicts if any
```bash
# Edit conflicted files
git add .
git commit
```

### 6. Push to your fork
```bash
git push origin main
```

## Conflict Resolution Strategy

### Files You've Modified
- `docs/daily-summaries/` - Your context preservation system
- `agents/` - Your multi-agent scaffolding
- `scripts/` - Your automation scripts
- `thoughtmarks/` - Your knowledge management system

### Files That May Conflict
- `src/` - Core application code (may need manual merging)
- `infra/` - Infrastructure templates (may need manual merging)
- `README.md` - May need to preserve your multi-agent documentation

### Resolution Approach
1. **Preserve your additions** - Keep your new files and directories
2. **Merge carefully** - For shared files, merge upstream improvements
3. **Test thoroughly** - Ensure your multi-agent system still works
4. **Update documentation** - Reflect any changes in your docs

## Best Practices

### Before Syncing
1. **Commit all local changes** - Don't sync with uncommitted work
2. **Create backup branch** - Always have a safety net
3. **Review upstream changes** - Understand what you're merging

### During Sync
1. **Resolve conflicts carefully** - Don't lose your multi-agent work
2. **Test functionality** - Ensure everything still works
3. **Update documentation** - Keep your docs current

### After Syncing
1. **Push to your fork** - Keep your fork updated
2. **Clean up backup branches** - Remove old backup branches
3. **Update daily summary** - Document the sync process

## Automation

The `scripts/sync-upstream.sh` script automates this process:

- ✅ Fetches upstream changes
- ✅ Creates backup branch
- ✅ Attempts automatic merge
- ✅ Handles conflicts gracefully
- ✅ Pushes to your fork

## Troubleshooting

### Merge Conflicts
If you get merge conflicts:

1. **Don't panic** - Conflicts are normal
2. **Review conflicts** - Understand what changed
3. **Resolve manually** - Edit conflicted files
4. **Test thoroughly** - Ensure everything works
5. **Commit and push** - Complete the sync

### Lost Changes
If you accidentally lose changes:

1. **Check backup branches** - Look for recent backup branches
2. **Use git reflog** - Find recent commits
3. **Restore from backup** - Checkout backup branch if needed

## Frequency

- **Weekly sync** - Recommended for active development
- **Before major releases** - Sync before releasing your multi-agent system
- **After upstream releases** - Sync when Azure-Samples releases updates

## Notes

- Your multi-agent scaffolding is designed to be independent of upstream changes
- The daily summaries system helps preserve context across syncs
- The thoughtmarks system provides persistent knowledge management
- Regular syncing helps you benefit from upstream improvements while maintaining your vision 