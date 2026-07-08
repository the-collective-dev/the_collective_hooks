---
name: c-health
description: Check session health and MCP connectivity. Use to verify The Collective is working properly.
---

Check the session health score by calling the `mcp__collective__collective_session_health` MCP tool.

This shows:
- Context health score (0-100%)
- Plans synced status
- Active objective status
- Work item counts
- Crash recovery readiness
- Suggestions to improve score

Use when:
- Session seems unresponsive
- After crashes/disconnects
- Verifying MCP setup
- Troubleshooting issues

High score (>70%) means good crash recovery. Low score? Follow suggestions to improve.
