---
name: codex-gemini-collab-rules
description: Use when planning external model handoff via collaborating-with-codex or collaborating-with-gemini.
---

# Codex/Gemini Collaboration Rules

## Load Conditions

Load when planning to invoke `collaborating-with-codex` or `collaborating-with-gemini` for external model collaboration.

## Mandatory Rules

1. If a `SESSION_ID` is returned, record it and explicitly decide whether to continue multi-turn conversation.
2. Never write to local filesystem via external model channels.
3. Require external models to return **unified diff patch** only for code changes; findings/recommendations only for analysis tasks.
4. Treat external model output as prototype; refactor to project style before applying.
5. Never directly apply sub-agent/external model output without local verification.
6. Do not claim fix or review readiness without concrete local verification evidence.
7. Strip or block any potential secrets from prompts/patches before handoff.

## Failure Handling

If required collaboration skill/tool is unavailable, skip this skill and continue with local tools only.