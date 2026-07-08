---
name: c-complete
description: Mark a work item as done. Triggers cascade updates to phase and plan progress.
---

Call the `mcp__collective__collective_complete_item` MCP tool to mark a work item as DONE.

Usage: /c-complete [workItemId]

This triggers cascade completion:
- Marks item as DONE
- If this completes a phase → phase marked COMPLETED
- If phase completion finishes plan → plan marked DONE
- Unblocks dependent items (READY)
- Returns suggested next work item

Use when you've fully completed a task.
