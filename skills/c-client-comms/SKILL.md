---
name: c-client-comms
description: Pre-send check for anything going to a client — status reports, delivery notes, proposals, update emails. Run it BEFORE the operator sends, to catch overclaims, tier conflation, asserted billing facts, and hidden internal notes. Derived from a reporting standard verified against real sent client reports. Args: <the draft, or the path/thread it lives in>.
---

Grade a client-facing draft against the reporting standard **before** it is sent. The design target: *a draft that confidently states an unverifiable fact is the failure mode.* Every rule below was derived from reviewing real sent client communication — several of them exist because a real report violated them.

You are a checker here, not a rewriter. Report what fails and why; let the operator decide the wording. Never send anything yourself.

## The truth-tier ladder (the #1 overclaim killer)

Every claim about work status carries exactly one tier, and tiers are never conflated:

`built / merged` → `live in production` → `delivered / accepted` → `paid`

These are four different facts. "Built, merged, and paid, but never actually deployed" is a real state — and describing it as "delivered" is a lie with extra steps. **When in doubt, claim the lower tier.**

## The pre-send checklist

1. **Verdict first.** The headline judgment leads — including the miss. Never bury a problem under a list of wins.
2. **Every claim carries its tier; every count carries a date.** A stale count stated confidently is an overclaim. "As of <date>" on every number.
3. **Render only what is verifiable.** Status from the evidence chain; shipped work from the repo. The most consequential facts are often *not* machine-reachable — billing truth lives in contracts, compliance status lives with the assessor — so those render as an explicit operator-to-fill placeholder, never asserted from system data.
4. **Never state a billing fact.** Do not assert an outstanding balance, a payment status, or an invoice state in a status report. If a payment nudge is warranted it is a separate, deliberate human decision — not a line inside a delivery note. *(This rule exists because a sent report asserted a balance the system could not verify.)*
5. **No auto-generated asks.** Whether to nudge a client to pay, accept, or decide is a per-client judgment call. A machine-drafted ask damages the relationship.
6. **Drafts are never auto-sent.** Human review and send, always.
7. **Zero cross-client bleed.** One client per artifact, structurally. Check for any other engagement's identifiers before it goes out.
8. **Self-corrections lead.** If a prior message overstated anything, the correction opens the next one — positioned under the verdict, not buried mid-body — before the client finds it themselves.
9. **Accountability language.** Causes are process and judgment. Never "the AI did X."
10. **Assume the client's AI reads everything.** Hidden-by-default is dead: client-side assistants surface internal sections, HTML comments, `display:none` speaker notes, and margin/strategy annotations. **Nothing ships in a client artifact that cannot survive the client reading it verbatim.** Internal notes either pass that test or move to a separate internal file.
11. **The verdict must be in the body, not only an attachment.** If substance lives in an attached document, the covering message still carries the headline judgment — that is what the client (and their assistant) reads first.
12. **The hidden-content sweep extends to attachments.** Attached HTML/PDF can carry presenter notes the body cannot. Sweep every attachment for hidden sections, comments, and internal markers before send.
13. **Degradation is explicit, never silent.** A missing data source becomes a labeled placeholder, never an invented value and never an error. A quiet week is reported as a quiet week — that is a fact, not a failure.

## Structure that passes

Greeting + "quick version up top" → **verdict/TL;DR** (headline judgment, each point tied to a concrete dated fact) → **corrections since last update** (or "nothing to correct") → **progress bucketed** (done and verified / in progress, with honest hedges / not started) → **what's still on us** (intentionally not-done-yet, owned plainly) → **what we need from you** (specific, human, decision-tied) → open questions + sign-off.

## Output

A pass/fail list against the rules above, each failure quoting the offending line and naming the rule. Flag anything you cannot verify rather than assuming it is fine — an unverifiable claim is the exact thing this check exists to catch.
