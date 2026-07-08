---
name: c-items
description: List work items with optional status filter. Use to see all tasks in the project.
---

Call the `mcp__collective__collective_work_items` MCP tool to list work items.

Optional filters:
- status: INBOX, BACKLOG, READY, IN_PROGRESS, DONE
- type: TODO, FEATURE, BUG, CHORE, SPIKE
- limit: number of items to return

Examples:
- /c-items - all items
- /c-items IN_PROGRESS - only in-progress items
- /c-items INBOX - all inbox items
