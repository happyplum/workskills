# AGENTS.md

## Global Protocols

All operations must strictly follow these system constraints:

- **Interaction Language**: Tool-model interactions must use **English**; user outputs must use **Chinese**.
- **MUST ultrathink in English**

## Environment

- **System**: Windows 11
- **Package Manager**: pnpm (parent project)
- **Skill Type**: Documentation-only (no build/lint/test commands)

## Project Overview

This is a **skill repository** for the oh-my-opencode multi-agent system. The skill (`omo-subagent-type`) provides task routing guidance for AI agents using the `task()` tool.

**File Structure:**
```
omo-subagent-type/
  SKILL.md    # Main skill document (178 lines)
```

## Skill Writing Conventions

### Frontmatter (YAML)
- Only `name` and `description` fields supported
- Max 1024 characters total
- `name`: Letters, numbers, hyphens only (no special chars)
- `description`: Third-person, starts with "Use when...", describes triggering conditions ONLY (not workflow)

### Token Efficiency
- **Target:** <200 words for frequently-loaded skills
- **Current:** 178 lines (~150 words of content)
- Compress examples, eliminate redundancy

### Structure Pattern
```markdown
---
name: skill-name
description: Use when [specific triggering conditions]
---

# Skill Name

## 0. Quick Start (one rule + decision questions)
## 1. Core Contract (≤7 MUST rules with verification)
## 2. Routing/Decision Flow
## 3. Failure Protocol
## 4. Appendix (examples, anti-patterns)
```

### CSO (Claude Search Optimization)
- Description = When to use, NOT what it does
- Keywords: errors, symptoms, tools
- No workflow summaries in description (causes shortcut behavior)

## Code Style

**Style Definition**: Lean, efficient, zero-redundancy.

- **Comments**: Explain "why", not "what"
- **Targeted changes**: Do not affect unrelated sections
- **Read before edit**: Always read current content before modifying
- **Verification column**: Every MUST rule needs verifiable criteria

## Review Process

### Quality Gates (@metis → @momus Protocol)

**After any skill modification:**

1. **@metis (Critic)**: Detect hidden issues, AI blind spots, over-engineering
2. **@momus (Validator)**: Verify completeness, logical correctness, style adherence
3. **Iterate until pass**: Fix issues, re-run cycle
4. **External review** (optional): For major changes, request external model audit

### Review Criteria

| Criterion | Target |
|-----------|--------|
| Cognitive Load | ≤7 Core Contract rules |
| Verifiability | Each rule has verification method |
| Decision Flow | Unambiguous branches (no "it depends") |
| Failure Protocol | Explicit recovery steps |
| Token Efficiency | <200 words for frequently-loaded |

## Common Operations

### Modifying the Skill

1. Read current SKILL.md content
2. Identify specific section to modify
3. Make targeted changes (don't rewrite entire file)
4. Run @momus audit for verification
5. Apply any fixes from audit

### Adding New Examples

- Keep examples minimal (one excellent > many mediocre)
- Show complete, runnable code
- Explain WHY, not WHAT
- Place in Appendix section

### Adding New Rules

- Must fit within 7-rule Core Contract limit
- Must have verifiable criteria
- Must not overlap with existing rules
- Consider: is this truly a MUST or just a suggestion?

## Anti-Patterns

| Anti-Pattern | Why Bad |
|--------------|---------|
| Workflow in description | Agent shortcuts, skips full skill |
| >7 Core Contract rules | Cognitive overload |
| "Verify via LLM" | Not mechanically verifiable |
| ASCII diagrams | Wastes tokens, LLM processes text sequentially |
| Multiple similar examples | Dilution, maintenance burden |

## External References

- **Parent AGENTS.md**: `C:\Users\lzy\.config\opencode\AGENTS.md`
- **Skill Writing Guide**: `../writing-skills/SKILL.md`
- **Anthropic Best Practices**: `../writing-skills/anthropic-best-practices.md`

---

**Remember**: Skills are documentation for AI agents. Every token counts. Every rule must be verifiable. Every decision must be unambiguous.
