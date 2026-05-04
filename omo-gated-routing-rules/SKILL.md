---
name: omo-gated-routing-rules
description: Use when deciding whether to work directly or delegate via task(), and when delegated work needs subagent selection or review gates.
---

# OMO Gated Routing Rules

## Load Conditions

Load this skill when deciding between direct tools and `task()` delegation, especially when subagent choice or review gates matter.

## Core Purpose

Choose the right execution path: direct tools for precise local work, delegation for research/routing work, and review for delegated output.

## Mandatory Rules

1. Decide direct vs delegated execution before acting.
2. Delegate one atomic task per `task()` call unless tasks are truly integrated; wait for completion before dependent actions.
3. When callable subagents exist, use `@explore` for repo discovery and `@librarian` for docs/OSS research.
4. If routing capability is unavailable, fall back to direct repo tools plus official docs/context7/web search without fabricating capabilities or duplicating delegated exploration.
5. For code-changing or decision-bearing delegated work, use review to validate output; prefer `metis` first for completion-status gap finding. If Metis finds plan-level gaps, use `oracle` next to deepen the analysis and produce structured plan-revision guidance, then land authoritative plan edits through the owning planning/repair path — specifically the plan owner or the `repairing-plans` skill for structural repair.
6. Cancel disposable background tasks individually, never with all-at-once cancellation.

## Failure Handling

- If routing capability is unavailable, skip this skill and use direct tools with explicit verification.
