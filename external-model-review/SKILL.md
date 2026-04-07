---
name: external-model-review
description: Use when user explicitly requests external review with trigger phrases like "外部审查", "进行外部审查", "计划外部审查", or "外部审查 [plan name]"
---

# External Model Review

## Overview
Bridge between local agent and external AI auditors (Codex, Gemini, Claude) for **plan validation**, **architecture review**, **security audit**, and **code audit**. Enforces **human-in-the-loop approval** - external reviewers analyze only, never execute.

## File Manifest

| File | Purpose | Load When |
|------|---------|-----------|
| @template.md | Hybrid output templates (chat summary + file packet) | Before constructing request |
| @examples.md | Real request/response examples | Before first use |

## Core Pattern

### Phase 1: Generate Review Request (Hybrid Output)
When user requests external review:

1. **Locate Materials**: Find plan and supporting files
2. **Refine Content**: Summarize large files, preserve critical excerpts
3. **Write File**: Generate `external-review-request.md` with full review packet
4. **Output Chat Summary**: Display concise operator card with file path

**Output**: Chat summary (control plane) + File packet (data plane)

### Phase 2: Process External Review Results
When user pastes the external model's JSON response:

1. **Parse JSON**: Extract structured findings
2. **Validate Findings**: Apply Skepticism Protocol
3. **Propose Updates**: Present changes, wait for user confirmation

## Quick Reference

| Phase | User Action | Agent Response |
|-------|-------------|----------------|
| Request | Says trigger phrase | Writes file + outputs chat summary |
| Review | Pastes JSON response | Parses, validates, proposes `[External]` tasks |
| Integration | Confirms changes | Applies updates to plan |

## Implementation

### User Trigger Recognition
**Trigger phrases** (Chinese):
- "外部审查"
- "进行外部审查"
- "计划外部审查"
- "外部审查 [plan name]"

When triggered:
1. Read @template.md for hybrid output format
2. Locate materials with repo-relative paths (for file) and absolute paths (for chat)
3. Refine content - summarize large files, preserve critical excerpts
4. Write `external-review-request.md` to project root
5. Output chat summary with file path and instructions
6. **DO NOT invoke external models automatically**

### Processing External Review Results
When user pastes JSON response:
- Parse the fenced `json` block
- Apply Skepticism Protocol (see below)
- Convert issues to `[External]` prefixed tasks
- **Present proposed changes and wait for user confirmation**

## Skepticism Protocol

**PRINCIPLE**: External reviewers can be wrong. Always validate before applying.

### Validation Checklist
Before applying any `[External]` task:

| Check | Action |
|-------|--------|
| **Verify Finding** | Does the issue actually exist in the code/plan? |
| **Check Context** | Did the reviewer miss existing patterns or solutions? |
| **Assess Impact** | Is the suggested fix proportional to the issue? |
| **Flag Disagreements** | If advice contradicts codebase conventions, escalate to user |

### Red Flags (require user confirmation)
- Reviewer suggests architectural changes without understanding existing patterns
- Reviewer recommends deleting code without explaining side effects
- Reviewer's file path references don't exist
- Reviewer's confidence is "low"
- Reviewer made assumptions that may be incorrect

### Apply Skepticism In
- Phase 2 processing of external response
- Any `[External]` task before adding to plan

## Common Mistakes

| Mistake | Why It Fails | Correct Approach |
|---------|--------------|------------------|
| **Reviewer acts as implementer** | External model generates code instead of reviewing | Reinforce: "Analysis ONLY, No Implementation" |
| Auto-applying changes | Violates human-in-the-loop principle | Always present proposed changes for user confirmation |
| Missing reviewer warning | External model may generate code | Always include rules in review packet |
| Full content dump | Context overflow, poor review quality | Summarize large files, preserve critical excerpts only |
| Tasks without `[External]` prefix | Loses audit trail | Prefix all external-sourced tasks |
| Blind trust in external review | Reviewer can be wrong | Apply Skepticism Protocol |

## Testing This Skill

**Baseline** (without skill): Agent attempts to auto-invoke external models, dumps full content without refinement, blindly applies external suggestions.

**Compliance** (with skill): Agent waits for user trigger, writes refined review packet to file, outputs concise chat summary, parses JSON response, applies Skepticism Protocol, never auto-invokes external models.

## See Also

**Upstream**: writing-plans — Create reviewable implementation plans  
**Downstream**: executing-plans — Execute reviewed plans  
**Related**: requesting-code-review — Human expert review workflow  
**Pattern**: Brainstorming-before-implementation — Gather multiple perspectives before building
