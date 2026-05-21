---
name: omo-subagent-type
description: "Use when calling task() to route work. Covers subagent_type selection, category selection, run_in_background, and load_skills configuration."
---

# omo-subagent-type

Use before ANY `task()` call to ensure valid schema, correct routing, and executable prompts. For coding work inside `subagent-driven-development`, that skill governs decomposition-first routing; this skill handles `task()` schema and category/subagent selection.

## 0. Quick Start

**One rule:** `task()` requires exactly one of `subagent_type` XOR `category`, plus `run_in_background`, `load_skills`, `description`, and `prompt`.

### Escalation Ladder

**Category cost order (default low→high):** direct tools → `quick` → `unspecified-low` → `unspecified-high` → `deep` → `ultrabrain`. Domain categories (`visual-engineering`, `artistry`, `writing`) override cost tiers — see Q4. Only escalate when lower-cost tiers are clearly insufficient.

### Decision Questions (answer in order)

```
Q1: Is file location known AND task is single-step (no discovery)?
    → YES: Use direct tools (read/grep/glob/edit). STOP.
    → NO: Continue to Q2.

Q2: Is the task primarily about this repo/worktree artifacts (code, docs, config, scripts)?
    → YES: Continue to Q3.
    → NO: What is the main need?
        - Retrieval (docs, examples, API reference) → subagent_type="librarian", run_in_background=true. STOP.
        - Reasoning/clarification → Continue to Q3.

Q3: What is the task type?
    → Search/discover patterns → subagent_type="explore", run_in_background=true
    → Clarify ambiguous request or critique/review → route to appropriate review agent, run_in_background=false
        - completion-status / omission check → `metis` first
        - post-`metis` deep review / plan-revision guidance → `oracle`
    → Architecture/debug or explicit escalation → route to appropriate escalation agent, run_in_background=false
    → Implement code → Continue to Q4.

Q4 (Implementation — domain categories override cost tiers):
    a) UI/UX/styling work (includes refactors, builds, large-scale UI) → category="visual-engineering"
    b) Non-conventional creative design → category="artistry"
    c) Documentation/prose → category="writing"
    d) Bounded, pattern-known (≤2 files, no architecture tradeoff) → category="quick"
    e) Multi-file, routine implementation → category="unspecified-low"
    f) Significant scope with moderate uncertainty → category="unspecified-high"
    g) Broad uncertainty + iterative discovery loops → category="deep"
    h) Hard reasoning (algorithms, formal tradeoffs, complex state machines) → category="ultrabrain"
    → Fallback (none match): category="unspecified-high"
```

### Minimal Valid Call

```typescript
task({
  subagent_type: "explore",  // XOR category
  run_in_background: true,
  load_skills: [],
  description: "Short summary",
  prompt: "[CONTEXT]: ...\n[GOAL]: ...\n[RETURN]: ..."
})
```

**Prompt fields:** `[CONTEXT]`/`[GOAL]`/`[RETURN]` required. Add `[SCOPE]`/`[SKIP]`/`[WHY_NOT_LOWER_COST]`/`[INPUT-ORIGINAL]` only when needed.

---

## 1. Core Contract (MUST — 7 rules)

| # | Rule | Verification |
|---|------|--------------|
| 1 | **XOR:** `subagent_type` OR `category`, never both | Schema check |
| 2 | **Required:** `run_in_background`, `load_skills`, `description`, `prompt` | Schema check |
| 3 | **Background:** `explore`/`librarian` = true; review/escalation agents/category = false | Agent type check |
| 4 | **Skills:** Only from `available_skills`; verify exact name; default `[]` unless task matches a skill's trigger | Cross-check list |
| 5 | **Prompt:** Must include `[CONTEXT]`, `[GOAL]`, `[RETURN]` | Field presence |
| 6 | **Language:** Prompt in English; quote non-English input via `[INPUT-ORIGINAL]` | LLM instruction |
| 7 | **Async:** Wait for system reminder before `background_output()`; never poll | Call sequence |

---

## 2. Agent & Category Guide

### Subagent Types

| Agent | When | Output |
|-------|------|--------|
| `explore` | Internal codebase search, pattern discovery | File paths + pattern summaries |
| `librarian` | External docs, OSS examples, API correctness | URLs + quoted excerpts |
| `metis` | Ambiguous request, need plan before coding, completion-status gap finding | Clarified requirements + omission review |
| `oracle` | Architecture tradeoffs, debugging, post-`metis` deep review, plan-revision guidance | Decision + reasoning + revision brief |
| `momus` | Plan review (when explicitly requested) | Pass/fail + fixes |

### Cost Guardrails

- Do **not** choose `deep` when task is mostly deterministic with known patterns.
- Route one independently verifiable bug at a time; never batch unrelated bugs into `deep`.
- Do **not** choose `ultrabrain` without explicit hard-logic evidence.
- Undecided between `quick` and `deep`? Choose `unspecified-low` first.
- Verification-only work (assertions, logs, checks) defaults to `quick`.
- **MUST:** any premium/high-cost route (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) requires `[WHY_NOT_LOWER_COST]` in prompt. *(Verification: field presence)*

### Plan-Execution Verification Exception

Match parent task's domain category. Downgrade to `quick` for CLI/log/assertion work; use `visual-engineering` for UI/screenshot validation. Include evidence destination and success gate in prompt.

---

## 3. Failure Protocol

1. **Read error** — Schema validation? Fix args. Subagent failure? Retry with more context.
2. **Add context** — Expand prompt sections before retry.
3. **Max 2 retries** — Then switch strategy: `explore` failed → `librarian`; `category` failed → review agent.
4. **Escalate** — After 3 total failures, escalate or ask user.
5. **Async discipline** — Do NOT plan dependent follow-up until system reminder arrives.

### Prohibited Behaviors

| ❌ Prohibited | Why |
|---------------|-----|
| `task(subagent_type=..., category=..., ...)` | XOR violation |
| `task(load_skills=["magic-skill"], ...)` | Invented skill |
| `run_in_background=true` then immediate `background_output()` | Polling blocks forever |
| Missing `[RETURN]` in prompt | Unstructured garbage |
| Silent retry without added context | Repeats same failure |
| Infinite agent chaining (A→B→C→D...) | Context dilution |
| Skipping `background_output()` after async task | Wasted work, no result |

---

## 4. Appendix

### Good Example

**Explore (internal search):**
```typescript
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Find auth middleware patterns",
  prompt: "[CONTEXT]: Adding JWT auth to REST API.\n[GOAL]: Find existing auth middleware and token flow.\n[SCOPE]: src/api/ and src/middleware/\n[SKIP]: test files\n[RETURN]: File paths + brief pattern description"
})
```

### Bad Example

```typescript
// ❌ WRONG: Using explore for known file
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Read tsconfig",
  prompt: "[GOAL]: Read tsconfig.json content"
})

// ✅ CORRECT: Direct tool
read({ filePath: "/absolute/path/to/tsconfig.json" })
```
