# External Model Review - Hybrid Output Templates

## Overview

This skill uses **hybrid output**: chat summary (control plane) + file packet (data plane).

**Control Plane (Chat)**: Concise operator card with file path, instructions, and wrapper prompt.
**Data Plane (File)**: Complete review packet with refined content, written to `external-review-request.md`.

---

# Template 1: Chat Summary (Control Plane)

Output this to chat when user triggers external review:

```markdown
## 📤 External Review Ready

**Review Goal:**
[One sentence describing what needs review and why]

**Focus Areas:**
- [Focus area 1]
- [Focus area 2]
- [Focus area 3]

**Review Packet:**
`[ABSOLUTE_PATH_TO_FILE]`

**Instructions:**
1. Open the file above (or copy its full contents)
2. Paste into Gemini, Codex, or Claude
3. Paste the JSON response back here

**Optional Wrapper Prompt:**
> Review the following markdown packet. Follow the "Required Output" section exactly. Analysis only. No implementation. No code patches.

---
```

---

# Template 2: Review Request File (Data Plane)

Write this to `external-review-request.md` in the project root:

```markdown
# External Review Request

## Reviewer Rules
- Analysis only.
- No implementation.
- No code patches.
- No file edits.
- No invented facts.
- If context is incomplete, state assumptions clearly.
- Use repo-relative paths only.

---

## Review Objective
[One short paragraph describing what needs review and why.]

---

## Questions To Answer
1. [Primary review question]
2. [Secondary review question]
3. [Optional targeted question]

---

## Scope

### In Scope
- [System, module, plan, or file group]
- [Specific decision or risk area]
- [Specific behavior or constraint]

### Out of Scope
- [Anything the reviewer should ignore]
- [Implementation details not needed]
- [Unrelated future work]

---

## Repository Context
- **Repo/Project:** [name]
- **Relevant Area:** [subsystem or feature]
- **Current State:**
  - [Bullet 1]
  - [Bullet 2]
  - [Bullet 3]
- **Key Constraints:** [stack, product, security, performance, timeline]

---

## Material Manifest
| Type | Path | Why It Matters |
|------|------|----------------|
| Plan | `path/to/plan.md` | Primary implementation plan |
| Research | `path/to/research.md` | Background and trade-offs |
| Notes | `path/to/notes.md` | Investigation findings |
| Evidence | `path/to/evidence.txt` | Supporting proof |
| Code | `path/to/code.ts` | Relevant implementation |

---

## Plan Summary
[Summarize the plan in 5-15 bullets. Do NOT paste full document unless very small.]

- [Key point 1]
- [Key point 2]
- [Key point 3]

---

## Research and Background
[Summarize ONLY findings that materially affect review quality.]

---

## Evidence

### Key Findings
- [Fact] — Source: `path/to/source`
- [Fact] — Source: `path/to/source`

### Selected Excerpts
```text
[path: src/service.ts]
[Paste ONLY the excerpt needed for review - max 50 lines]
```

```text
[path: plan.md]
[Paste ONLY the critical section - max 30 lines]
```

---

## Known Risks or Open Questions
- [Known risk or uncertainty]
- [Open question]

---

## Review Priorities
- Prioritize correctness over completeness.
- Prioritize blockers over style issues.
- Prioritize concrete evidence over generic advice.
- Flag ambiguity when it changes the recommendation.

---

## Required Output

Return **exactly one** fenced `json` block and nothing else.

```json
{
  "reviewer": {
    "model": "string",
    "review_type": "architecture|security|performance|code_quality|plan",
    "confidence": "high|medium|low",
    "date": "YYYY-MM-DD"
  },
  "summary": {
    "verdict": "approve|approve_with_changes|needs_revision|block",
    "score": 0,
    "one_sentence_rationale": "string"
  },
  "issues": [
    {
      "id": "I1",
      "severity": "critical|major|minor",
      "title": "string",
      "path": "repo/relative/path.ext or N/A",
      "evidence": "string",
      "why_it_matters": "string",
      "recommended_change": "string"
    }
  ],
  "open_questions": [
    "string"
  ],
  "assumptions": [
    "string"
  ]
}
```

### Output Rules
- Output English only.
- Output exactly one fenced `json` block.
- Use repo-relative paths only.
- Use empty arrays when there are no items.
- Do not include code patches.
- Do not restate the full prompt.
- Do not add markdown outside the `json` block.
```

---

# Content Refinement Heuristics

When constructing the review packet, apply these rules:

## File Size Limits

| Content Type | Max Lines | Action if Exceeded |
|--------------|-----------|-------------------|
| Plan Summary | 30 lines | Bullet summary only |
| Research Summary | 20 lines | Key findings only |
| Each Code Excerpt | 50 lines | Trim to relevant functions |
| Each Evidence Block | 30 lines | Summarize, show key snippet |

## What to Include

**ALWAYS Include:**
- Architectural decisions and rationale
- Security-sensitive code sections
- Performance-critical paths
- Error handling logic
- Integration points

**NEVER Include:**
- Boilerplate code
- Auto-generated files
- Test fixtures
- Full configuration files (show relevant sections only)
- Import statements (unless relevant to the issue)

## Path Convention

| Context | Path Format | Example |
|---------|-------------|---------|
| File content (review packet) | Repo-relative | `src/auth/service.ts` |
| Chat summary | Absolute (Windows) | `C:\project\src\auth\service.ts` |

---

# Usage Summary

## For Local Agent

1. **Locate** all relevant files
2. **Refine** content using heuristics above
3. **Write** `external-review-request.md` with Template 2
4. **Output** chat summary with Template 1
5. **Wait** for user to paste JSON response

## For User

1. Open the file or copy its contents
2. Paste into external model (Gemini, Codex, Claude)
3. Copy the JSON response
4. Paste back to this agent

## For External Model

1. Review all materials
2. DO NOT generate code or modify files
3. Return exactly one JSON block
4. Include confidence score and assumptions
