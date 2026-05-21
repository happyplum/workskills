---
name: sisyphus-cleanup
description: Use when cleaning, auditing, pruning, or deleting a `.sisyphus` workspace or similar execution-artifact directory, especially when the request involves removing completed plans, evidence, state files, empty folders, or preserving only deduplicated long-term knowledge before deletion.
---

# Sisyphus Cleanup

## Overview

Clean `.sisyphus` as **verification-first artifact reduction**, not blind file purge. Core rule: **inventory → verify status → deduplicate durable knowledge → delete transient artifacts → prove cleanup**.

## Load Conditions

Load when any is true:

- User asks to clean, prune, archive, reset, or remove `.sisyphus` content
- Directory contains plans, notepads, evidence, state files, or empty folders that may be obsolete
- User wants to keep only useful architecture notes while deleting completed execution artifacts
- Cleanup decision depends on whether items are completed, active, duplicated in memory, or safe to delete

## Mandatory Rules

1. Start from full inventory. Do NOT classify from filenames alone.
2. Verify completion in code/repo reality before deleting plans or notepads.
3. Treat `boulder.json`, plan files, evidence, notes as **state-bearing** until proven disposable.
4. Preserve durable architecture knowledge only after checking existing memories for overlap.
5. Do not mirror task logs into memory. Keep only durable `guardrails`, `reference`, `topology`, `contract` knowledge.
6. Delete transient artifacts only after unique value disproven or preserved elsewhere.
7. Remove empty directories only after confirming truly empty.
8. End with proof: show remaining directory state or verify directory no longer exists.

## Classification Pass

Classify each item **after verification**:

- **Active state** — current plan/session state, live checkpoint, in-use artifact → keep
- **Completed transient artifact** — finished plan, evidence output, execution log, stale tracker → delete
- **Durable knowledge** — architecture, anti-regression lesson, topology, reusable rule → preserve via existing/updated memory
- **Unknown** — cannot prove status yet → keep until verified

## Execution Order

1. **Inventory**: List full `.sisyphus` tree; identify plans, notepads, evidence, state files, empty directories

2. **Verify status, don't infer**: Confirm work actually complete in code/repo; check if `boulder.json` still points at active work; even if user says "completed", still verify

3. **Review durable knowledge before deletion**: Read existing memories first; if durable knowledge exists, do NOT duplicate; if notes contain unique long-term value, compress into focused memory updates; use `memory-restructuring` principles: one memory = one dominant responsibility

4. **Delete only verified transient artifacts**: Delete completed plans, stale notepads, evidence outputs, disposable state files only after steps 2-3; remove empty directories after confirming empty; if `.sisyphus` becomes empty, remove root directory too

5. **Prove result**: List remaining contents of `.sisyphus`, or verify `.sisyphus` no longer exists; report deleted, preserved, why no durable knowledge lost

## Deletion Checklist

Delete only if **all** are true:

- Status verified, not assumed
- Not current source of active execution state
- Any unique durable knowledge preserved or proven redundant
- Removal reduces noise without creating second source of truth
- Post-cleanup state verifiable immediately

If uncertain, keep and mark for follow-up.

## Memory Handling Protocol

Sequence before preserving note-derived knowledge: `list_memories` → `read_memory` overlapping → decide (keep existing/update existing/write new/write nothing) → execute → only then delete source

**Do not store**: session IDs, one-off execution logs, temporary audit notes, verification output text, giant copied plan histories

## Report Structure

Report when complete: verified before deletion → deleted → durable knowledge preserved/intentionally not preserved → final proof (`remaining tree` or `path does not exist`)

**Boundary**: Use memory-restructuring for store-level reorganization across multiple memories; use sisyphus-cleanup for .sisyphus artifact reduction. When cleanup reveals durable knowledge gaps, use memory-restructuring principles for preservation step.