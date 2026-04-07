# AGENTS.md - External Model Review Skill

## Project Overview

This is an OpenCode skill repository that bridges local agents with external AI auditors (Codex, Gemini, Claude) for plan validation, architecture review, security audit, and code audit.

**Core Principle**: External reviewers analyze only - never execute. Human-in-the-loop approval is mandatory.

## Repository Structure

```
external-model-review/
├── SKILL.md          # Main skill definition (YAML frontmatter + markdown)
├── template.md       # Hybrid output templates (chat summary + file packet)
├── examples.md       # Real-world usage examples
├── evals/
│   └── evals.json    # Test cases for skill validation
└── AGENTS.md         # This file
```

## Build/Test Commands

**No build system** - this is a documentation-only repository.

### Validation

```bash
# Validate JSON syntax
node -e "JSON.parse(require('fs').readFileSync('evals/evals.json'))"

# Check markdown structure
# - SKILL.md must have YAML frontmatter with `name` and `description`
# - template.md must contain "Template 1" and "Template 2" sections
# - examples.md must have at least 2 examples
```

### Running Evals

No automated test runner. Validate manually:
1. Read each test case from `evals/evals.json`
2. Simulate the prompt against the skill behavior
3. Verify `expected_output_contains` strings appear in output
4. Verify `expected_not_contains` strings do NOT appear

## Code Style Guidelines

### Markdown Files

**Headers:**
- Use `#` for document title (one per file)
- Use `##` for major sections
- Use `###` for subsections
- Maximum 3 levels of nesting

**Tables:**
- Always include header row
- Use `|` with spaces: `| Column | Value |`
- Align columns consistently

**Code Blocks:**
- Always specify language: ```markdown, ```json, ```bash
- Use fenced blocks (```) never indented code

**Lists:**
- Use `-` for unordered lists
- Use `1.` for ordered lists (not `1)`)
- Single space after marker

### JSON Files

**Structure:**
```json
{
  "test_cases": [
    {
      "name": "Descriptive Test Name",
      "prompt": "User prompt to test",
      "expected_output_contains": ["string1", "string2"],
      "expected_not_contains": ["bad_string"]
    }
  ]
}
```

**Rules:**
- 2-space indentation
- No trailing commas
- Keys in snake_case
- String values use double quotes

### SKILL.md Specific

**Required Frontmatter:**
```yaml
---
name: skill-name
description: Trigger description with Chinese phrases
---
```

**Required Sections:**
1. `## Overview` - Purpose and scope
2. `## File Manifest` - Table of related files
3. `## Core Pattern` - Phase 1 and Phase 2 workflows
4. `## Implementation` - Detailed instructions
5. `## Common Mistakes` - Table of anti-patterns
6. `## Testing This Skill` - Baseline vs Compliance

**Chinese Trigger Phrases:**
- Keep trigger phrases in Chinese (e.g., "外部审查")
- All other content in English
- Exception: User-facing examples may include Chinese context

### template.md Specific

**Template Structure:**
- `# Template 1: Chat Summary` - Control plane output
- `# Template 2: Review Request File` - Data plane output
- `# Content Refinement Heuristics` - Size limits and rules
- `# Usage Summary` - For each actor (agent, user, external model)

**Path Conventions:**
| Context | Format | Example |
|---------|--------|---------|
| File content | Repo-relative | `src/auth/service.ts` |
| Chat summary | Absolute (Windows) | `C:\project\src\auth\service.ts` |

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| File names | kebab-case | `external-model-review`, `evals.json` |
| Section headers | Title Case | `## Skepticism Protocol` |
| JSON keys | snake_case | `expected_output_contains` |
| Task prefixes | `[External]` | `[External-CRITICAL] Fix issue` |

## Error Handling

**In Skill Definition:**
- Always provide "Correct Approach" for each "Common Mistake"
- Use tables for clarity: `| Mistake | Why It Fails | Correct Approach |`

**In Templates:**
- Include "Red Flags" section for validation
- Provide fallback instructions when assumptions fail

## Key Constraints

1. **Human-in-the-loop**: Never auto-apply external suggestions
2. **Skepticism Protocol**: Always validate external findings before applying
3. **Hybrid Output**: Chat summary (concise) + File packet (detailed)
4. **JSON Response**: External models must return strict JSON format
5. **Path Privacy**: Use repo-relative paths in files, absolute in chat

## Editing This Skill

When modifying skill files:

1. **SKILL.md changes**: Update `File Manifest` table if adding new files
2. **template.md changes**: Ensure both templates stay consistent
3. **examples.md changes**: Include full request/response cycle
4. **evals.json changes**: Add corresponding test cases for new features

### Validation Checklist

- [ ] JSON syntax valid (no trailing commas)
- [ ] Markdown renders correctly
- [ ] All `@file` references exist
- [ ] Chinese trigger phrases preserved
- [ ] English for non-trigger content
- [ ] Tables have consistent column counts
- [ ] Code blocks have language specified

## External Dependencies

None - this is a self-contained skill repository.

## Related Skills

- `writing-plans` - Creates reviewable implementation plans
- `executing-plans` - Executes reviewed plans
- `requesting-code-review` - Human expert review workflow
