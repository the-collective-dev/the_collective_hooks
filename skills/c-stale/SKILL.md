---
name: c-stale
description: Check if the current objective is stale based on recent git commits. Use for mid-session health checks.
---

Call the `mcp__collective__collective_detect_stale_objective` MCP tool to check if the current objective may be stale.

Compares:
- Current objective text
- Recent git commits (last 10)

Returns:
- Staleness confidence (high/medium/low/none)
- Evidence from commits
- Suggested updated objective (if stale)

Use during mid-session health checks to ensure objective stays current with your actual work.
