---
name: c-change-note
description: Draft a change note when a client asks for something outside the signed scope. Use the moment new scope appears in a client message, call, or thread — before writing any code for it. Enforces the scope boundary (free-vs-new), objective acceptance criteria, and the written-go rule. Args: <what the client asked for> [engagement/SOW ref].
---

Turn a client's ask into a written change note that can be approved in one reply. **The discipline this protects: no build starts on a verbal yes, and no new capability quietly rides in as "a small fix."** Silent scope creep is the single most common delivery leak — it costs margin, it corrupts the milestone record, and it is invisible until someone audits the engagement.

## When this fires

The moment a client asks for something that is **not** (a) a defect in already-delivered scope, or (b) inside a stated acceptance/tuning window. If it is new capability, it is a change note — *even if it is small, even if the client is delighted, even if you already know exactly how to build it.*

**Classify, don't decide alone.** You flag the boundary and draft; the operator prices it and the client approves it in writing. If the classification is genuinely ambiguous (is this a defect or a new feature?), say so explicitly in the draft and let the operator rule — an ambiguous item silently classified as "free" is how the boundary erodes.

## The eight lines every change note carries

1. **What they asked for** — in their words, quoted, with the source and date (email/call/thread). Their language, not your paraphrase.
2. **In-scope vs new — and why** — state plainly why this falls outside current scope, referencing the phase's "does NOT include" list if one exists. *Name the free work as free in the same note*, so the client sees the boundary being applied consistently rather than only when it costs them.
3. **What it reuses** — the honest build-cost story (an existing matcher, an existing model, existing UI). Reuse is usually why the number is modest; saying so makes the number legible instead of arbitrary.
4. **The open variable** — the one design decision that actually moves the estimate, asked as a question the client can answer in a sentence. One question, not a questionnaire.
5. **The number** — firm, or a tight range. **The operator sets price; never invent one.** If you are drafting ahead of the operator's pricing, mark it clearly as a placeholder for them to set, in a form that cannot be mistaken for a quote.
6. **Objective acceptance criteria** — what "done" means, in testable terms, agreed *before* build. A milestone whose acceptance is subjective becomes a payment argument later.
7. **What it does NOT include** — with a *reason* per exclusion. Exclusions carrying a reason resist re-litigation; a bare "not included" list invites it.
8. **Written go required** — state it in the note. No build begins on a verbal or in-passing yes.

## Hard rules

- **No build before written approval.** Verbal agreement on a call is the most common failure mode; a call transcript makes it detectable, but the discipline is the actual fix.
- **No retroactive billing. No silent creep.** A change note may adjust cost up, down, or not at all — publish the direction honestly.
- **Capture, don't fence.** Ideas that fall outside this note get logged as future scope with a named home (a later phase, a future SOW) — never dismissed, and never quietly absorbed into current work. Clients raise good roadmap items ahead of schedule; the correct response is to record them, not to build them now or wave them off.
- **Expect the itemization to be edited.** Clients who build things themselves treat an itemized note as a design surface: they will strike lines, reorder, and defer with conditions attached. That is co-design working, not haggling. Validate their sequence rather than defending yours.
- **One note, one ask.** Bundling several asks into one number makes it un-strikeable and slows approval.

## Output

A draft the operator can review and send, plus a one-line summary of what is free versus what is priced, so the boundary is visible at a glance. Do not send it, and do not begin implementation, until the operator has priced it and the client's written go is on record.
