---
name: doc-sync
description: Use when a significant implementation, refactor, or plan has completed and documentation, plan files, or persistent project memory may no longer match verified code reality; also use when the user says "sync docs", "update docs", "post-completion review", "audit stale docs", "文档同步", or "完成后审查".
---

# Doc Sync

Post-completion documentation and memory sync audit. Compares verified code reality against all context carriers, detects drift, produces prioritized sync report. Default audit-only; fixes require explicit approval.

**Core principle:** Verified code reality beats stale documentation. Roadmap/vision material is not drift if clearly labeled aspirational.

**This skill SHOULD be invoked during Completion Gate when context synchronization is a gate condition.**

## Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| `audit` | Default | Produce drift report only |
| `fix` | User explicitly says "fix/apply/update" | Audit + apply verified fixes |

Optional inputs: `fix`, `range=<git-range>` (e.g. `origin/main...HEAD`), `carrier=<class>` (e.g. `readme`, `agents`, `docs`, `plans`). When carrier specified, others listed as "not audited — filtered out".

## Workflow

### 1. Establish Evidence Baseline

Read root + nearest local `AGENTS.md`, relevant `README.md` product spec sections. Identify plan files (common locations: `.sisyphus/plans/`, `docs/plans/`, project root `*.plan.md`, or paths named in AGENTS). Check for persistent memory system.

Extract: required carriers, sync rules, completion gate rules, doc boundaries.

### 2. Determine Implementation Surface

```
git diff --stat <range>    # file-level change surface
git diff --name-only <range>
```

Identify touched packages/modules/services/routes, added/removed endpoints/workflows/pages, completed gaps. Prioritize docs for changed surface — do NOT scan whole repo.

If no range determinable (fresh repo, single commit), audit ALL default carriers against current code state and note this in report.

### 3. Build Carrier Inventory

Use project-named carriers first. Defaults if none named:

| Class | Files |
|-------|-------|
| `readme` | Root + nearest package `README.md` |
| `agents` | Root + local `AGENTS.md` |
| `docs` | `docs/**` (roadmap, architecture, gap-analysis, requirements, API) |
| `plans` | Plan/spec/progress files |
| `memory` | Persistent agent memories or context stores |

### 4. Classify Before Judging

Determine if content is **descriptive** (current truth), **normative** (rules), **aspirational** (roadmap/proposal), or **historical** (changelog). Only descriptive/normative contradicted by reality is drift. Aspirational is drift only if written as present reality.

### 5. Audit for Drift

For each carrier, compare claims vs verified code/config/plan. Look for:
- "not implemented"/"future"/"gap"/"TODO" statements now false
- Missing routes/endpoints/services/workflows/config surfaces
- Stale "Known Gaps"/"Limitations"/"Tech Debt"/"Unsupported" sections
- Workflow descriptions no longer matching execution
- Service tables/command lists missing new surfaces
- Plan checkboxes not updated, evidence missing
- Memory entries encoding overturned conclusions

### 6. Rate Severity

| Priority | Definition |
|----------|------------|
| **critical** | Wrong rules likely to mislead implementation/ops immediately |
| **high** | Materially incorrect current-state docs; major features missing |
| **medium** | Incomplete summaries, stale gap lists, partial drift |
| **low** | Wording cleanup, minor omissions, cosmetic issues |

### 7. Produce Sync Report

```
## Scope — mode, git range, areas touched
## Drift Summary — Critical/High/Medium/Low counts
## Findings — per file: [PRIORITY] path | claim type | drift | evidence | fix | status
## Memory Sync — backend status, actions needed (update/invalidate/delete)
## Unresolved — items needing human judgment
## Completion — docs/memory updated? manual follow-up needed?
```

Status values: `audit-only` | `fix-ready` | `fixed` | `manual-decision-needed`

### 8. Apply Fixes (fix mode only)

Update only claims backed by evidence. Preserve document intent. AGENTS parity → both files. Plan checkboxes → only when verified. Memory writable → update; unavailable → record as pending.

### 9. Re-check

Verify changed docs internally consistent. No carrier still states old truth. Aspirational docs still clearly labeled.

## Carrier Checklist

| Carrier | Check |
|---------|-------|
| README/Product Spec | Shipped status, routes/endpoints, service tables, commands/setup, gaps/tech-debt, architecture |
| AGENTS | Workflow truths, local rules, carrier list, sync/completion rules |
| docs/** | Roadmap state, gap analysis, requirements baseline, API docs, architecture, migrations |
| Plan files | Checkboxes, evidence, deferred items, acceptance criteria |
| Memory | Architecture/gap/rule conclusions current, outdated invalidated, new conventions recorded |

## Decision Rules & Edge Cases

**Precedence:** User instruction > verified code reality > existing docs > agent inference. Ambiguity → `manual-decision-needed`.

| Situation | Action |
|-----------|--------|
| Aspirational doc written as present reality | Flag — not drift if clearly labeled, but is drift if reads as current truth |
| Feature behind feature flag | "implemented, gated by [flag]" — not "fully shipped" |
| Feature partially shipped (some routes exist, some planned) | Document each surface's actual state individually |
| Code disagrees with plan | Code reality wins for docs. Plan checkboxes need separate evidence |
| No memory backend | Report actions as pending |
| Multi-language AGENTS | Both must be checked. Single-language change = high finding |
| No git range determinable | Audit all defaults, note limitation |

## Red Flags

- "Tests passed, so docs are probably fine"
- "README is enough"
- "Roadmap language is close enough"
- "Memory can be updated later"

These mean drift is being normalized. Stop and audit.
