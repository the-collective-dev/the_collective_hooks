---
name: c-assess
description: Production-readiness assessment of a whole repo — A–F across 10 domains with depth tiers, evidence-gated. Use for take-over / second-opinion / "is this safe for production" reviews. Args: <repo path or owner/repo> [focus: full|security|take-over|finish-it].
---

Run a **verified** production-readiness assessment. The value is NOT the grading — it is the verification discipline: grade what you VERIFY, not what the docs claim. The structural gates are enforced SERVER-SIDE by `collective_assess_codebase` (they cannot be skipped); your job is to gather honest evidence and choreograph the run.

## The gates (applied server-side — know them so your evidence survives them)
- A domain cannot be 🟢 Deep without a recorded **evidence command** (a test run, a `gh run` check, a file read) — otherwise it is downgraded to 🟡 Sampled.
- **Security & Scalability cap at 🟡 on a static pass** — 🟢 requires live IDOR/session or load testing (`collective_assess_live`, consent-gated).
- Every finding needs a **confidence tag** (CONFIRMED / INFERRED / UNVERIFIED) — untagged findings are dropped.
- Tests & Code-Hygiene refuse to grade (INSUFFICIENT-EVIDENCE) without a real local test-suite run AND a CI run-history check.

## Steps

1. **Run-it gate (do this FIRST — it unlocks two domains).** In the local checkout: install deps if needed, run the FULL test suite and record passed/failed/skipped + the exact command; attempt a typecheck/build; check CI reality with `gh run list` (pass rate over the last ~10 runs).

2. **Start the server-side assessment** (primary path — works for private repos via the platform's GitHub credentials):
   Call `collective_assess_codebase` with:
   - `runServerSide: true`, `repo: "owner/repo"`, optional `ref`
   - `evidence: { tests: { passed, failed, skipped, total, command }, build: { ok, command } }` — from step 1
   - optional `focus` (full | security | take-over | finish-it) and `depth` (deep default; quick for a first look)
   - `clientHtml: true` if a client-facing scorecard deliverable is wanted
   A preflight verifies the repo is clonable BEFORE starting; if it refuses, the error tells you exactly what to do (grant access, or fall back to step 4).

3. **Track it honestly.** Note the returned workflowId and check `collective_workflow_status` — it reports RUNNING progress, wedges, and FAILED causes truthfully. Do not poll artifacts blindly; do not invent progress narratives. KNOW THE RECALL LIMIT: a single run is a sample, not a census — reviewers read different files per run, and a re-run can miss findings a prior run verified. Operator-verified findings from prior runs remain source of truth even when a re-run misses them; never let a re-run silently retire a verified finding. On completion the scorecard lands as a tracked artifact (ASSESS-NNN) with P0/P1 remediation work items, plus a grade trend vs. prior runs.

4. **Fallback — operator-side synthesis** (no server clone needed; you have the code locally). FIELD CALIBRATION (2026-06-05, same repo assessed both ways 24h apart): operator-side grades inflate ~1 letter — self-graded B+ vs deep-server C+ — because nothing catches doc-sourced findings you did not reconcile against code. Treat operator-side grades as PROVISIONAL; re-run server-side before locking a grade or showing a client. For Domain/Money Correctness specifically, audit the payment/billing/webhook code paths directly — the inflated run missed a Deep-verified double-charging finding entirely. Then: gather per-domain findings yourself with file:line citations and confidence tags, re-grepping any doc claim against HEAD before it affects a grade (docs are stale until proven), then pass them as `domains[]` (each {key, grade, depth, consequence, findings[], evidenceCommand?, liveTested?}) WITHOUT runServerSide. The same gates apply server-side to your submission.

5. **Present the verdict** tied to the operator's actual business question (safe to take over? safe to ship? what must be fixed first?), including the trustworthiness map and "what was NOT audited" — the report carries them for a reason.
