---
name: c-complete
description: Mark a work item as done — after verifying it actually is. Triggers cascade updates to phase and plan progress, so an unverified DONE propagates.
---

Mark a work item DONE via the `mcp__collective__collective_complete_item` MCP tool.

Usage: /c-complete [workItemId]

## Verify before you claim

This is the first rung of a four-rung ladder, and the rungs are not the same thing:

**built ≠ merged ≠ live in prod ≠ delivered/accepted**

Marking DONE cascades — item → phase → plan → unblocks dependents → feeds the status reports a client may read. An unverified DONE doesn't stay local; it becomes platform truth and then a claim to someone paying for the work. Overclaiming here is how a status report says "shipped" for something that merged but never deployed.

**Before calling the tool, state which rung you are actually on and name the receipt.** The merge commit or PR number, the passing CI run, the deploy that carried it, the live check you ran, or the acceptance you received. If you can't name one, you are not done — say what's missing instead.

- Wrote the code, tests pass locally → **built**, not done.
- PR merged → **merged**. Does this repo auto-deploy, or does it need a promote step?
- Deployed → **live**. Did you verify against the running system, or are you assuming the deploy carried it? "It probably worked" is not verification — check the endpoint, the row, the log line.
- Operator/client confirmed it meets the acceptance criterion → **delivered**.

Which rung DONE requires is the item's own definition of done — a spike may be done at "built"; a client deliverable is not done until accepted. Read the item's acceptance criteria first. If it has none, say which rung you reached and let the operator decide.

## What the tool does

- Marks the item DONE
- If this completes a phase → phase marked COMPLETED
- If phase completion finishes the plan → plan marked DONE
- Unblocks dependent items (READY)
- Returns the suggested next work item

## Related

- `/c-items` — read the item's acceptance criteria before completing it
- `/c-ready` — see what the cascade unblocked
