---
name: c-sync
description: Sync local plans to The Collective database. Use after creating or updating plan files.
---

Call the `mcp__collective__collective_sync_plans` MCP tool to sync local plans to The Collective database.

This reads plan files from:
- collective/plans/
- .claude/plans/

And syncs them to the cloud for:
- Work item tracking
- Phase progress
- Plan status
- Cross-session persistence

Run this after:
- Creating new plan files
- Updating existing plans
- Plan mode completion
