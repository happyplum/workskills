---
name: codex-gemini-collab-rules
description: Use when planning external model handoff via collaborating-with-codex or collaborating-with-gemini.
---

# Codex/Gemini Collaboration Rules

## Load Conditions

Load this skill when you plan to invoke `collaborating-with-codex` or `collaborating-with-gemini` for external model collaboration.

## Minimal CSO Triggers

Primary keywords: `collaborating-with-codex`, `collaborating-with-gemini`, `external model`, `SESSION_ID`, `unified diff patch`.

Secondary keywords: `prototype output`, `sandbox security`, `model handoff`, `multi-turn external review`.

## Counter-Examples (Do Not Trigger)

| Input Pattern | Do Not Trigger Because |
|---|---|
| "直接在本地修一下" | No external model collaboration requested |
| "帮我读一下这个文件" | Local read-only task, no Codex/Gemini handoff |
| "解释一下这个报错" | Analysis-only request without external delegation |

## Mandatory Rules

1. If a `SESSION_ID` is returned, record it and explicitly decide whether to continue multi-turn conversation.
2. Never write to local filesystem via external model channels.
3. When requesting code changes, require external models to return **unified diff patch** only; for analysis/review-only tasks, require findings or recommendations only and never raw file overwrite instructions.
4. Treat external model output as prototype; refactor to project style before applying.
5. Never directly apply sub-agent/external model output without local verification.
6. Do not claim fix or review readiness without concrete local verification evidence (readback/diff/tests as applicable).
7. Strip or block any potential secrets from prompts/patches before handoff.

## Verification Signals

- `SESSION_ID` is captured whenever multi-turn continuation is intended.
- Returned code artifact is patch-form (not raw file overwrite instruction).
- Local verification evidence exists before adoption of external suggestions.

## Failure Handling

- If required collaboration skill/tool is unavailable, skip this skill and continue with local tools only.
