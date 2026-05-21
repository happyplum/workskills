---
name: external-model-review
description: Use when user explicitly requests external review with trigger phrases like "外部审查", "进行外部审查", "计划外部审查", or "外部审查 [plan name]"
---

# External Model Review

## Overview

Bridge between local agent and external AI auditors (Codex, Gemini, Claude) for **plan validation**, **architecture review**, **security audit**, **code audit**. Enforces **human-in-the-loop approval** - external reviewers analyze only, never execute.

## File Manifest

| File | Purpose | Load When |
|------|---------|-----------|
| @template.md | Hybrid output templates (chat summary + file packet) | Before constructing request |
| @examples.md | Real request/response examples | Before first use |

## Core Pattern

### Phase 1: Generate Review Request (Hybrid Output)

When user requests external review: Locate materials → Refine content (summarize large files, preserve critical excerpts) → Write `external-review-request.md` with full review packet → Output chat summary (operator card with file path). Output: chat summary (control plane) + file packet (data plane).

### Phase 2: Process External Review Results

When user pastes external model's JSON response: Parse JSON → extract structured findings → Apply Skepticism Protocol → Propose updates → Wait for user confirmation.

## Quick Reference

| Phase | User Action | Agent Response |
|-------|-------------|----------------|
| Request | Says trigger phrase | Writes file + outputs chat summary |
| Review | Pastes JSON response | Parses, validates, proposes `[External]` tasks |
| Integration | Confirms changes | Applies updates to plan |

## User Trigger Recognition

**Trigger phrases** (Chinese): "外部审查", "进行外部审查", "计划外部审查", "外部审查 [plan name]"

When triggered: Read @template.md for hybrid output format → Locate materials with repo-relative (file) and absolute (chat) paths → Refine content (summarize large files, preserve critical excerpts) → Write `external-review-request.md` to project root → Output chat summary with file path and instructions.

When user pastes JSON response: Parse fenced `json` block → Apply Skepticism Protocol → Convert issues to `[External]` prefixed tasks → **Present proposed changes and wait for user confirmation**.

## Skepticism Protocol

**PRINCIPLE**: External reviewers can be wrong. Always validate before applying.

### Validation Checklist

Before applying any `[External]` task:

| Check | Action |
|-------|--------|
| **Verify Finding** | Does issue actually exist in code/plan? |
| **Check Context** | Did reviewer miss existing patterns or solutions? |
| **Assess Impact** | Is suggested fix proportional to issue? |
| **Flag Disagreements** | If advice contradicts codebase conventions, escalate to user |

### Red Flags (require user confirmation)

- Reviewer suggests architectural changes without understanding existing patterns
- Reviewer recommends deleting code without explaining side effects
- Reviewer's file path references don't exist
- Reviewer's confidence is "low"
- Reviewer made assumptions that may be incorrect

### Apply Skepticism In

Phase 2 processing of external response and any `[External]` task before adding to plan.

## Common Mistakes

| Mistake | Why It Fails | Correct Approach |
|---------|--------------|------------------|
| **Reviewer acts as implementer** | External model generates code instead of reviewing | Reinforce: "Analysis ONLY, No Implementation" |
| Auto-applying changes | Violates human-in-the-loop principle | Always present proposed changes for confirmation |
| Missing reviewer warning | External model may generate code | Always include rules in review packet |
| Full content dump | Context overflow, poor review quality | Summarize large files, preserve critical excerpts only |
| Tasks without `[External]` prefix | Loses audit trail | Prefix all external-sourced tasks |
| Blind trust in external review | Reviewer can be wrong | Apply Skepticism Protocol |