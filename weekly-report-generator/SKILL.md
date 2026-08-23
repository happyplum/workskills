---
name: weekly-report-generator
description: >-
  Generate a Chinese weekly work report from Git history and verified project evidence. Use this skill whenever the user asks for 周报、周工作总结、本周工作、提交汇报、迭代总结、工作量汇报, or wants to turn their commits into a leader-readable report. The default period is the latest completed Sunday through the preceding Sunday; if the user gives an explicit date range, always use that range instead. Preserve technical difficulties and independently meaningful workstreams, but do not dump commit hashes, detailed per-item dates, or raw Git history unless the user asks for them.
---

# Weekly Report Generator

## Purpose

Turn a developer's Git activity into a report that a manager can understand without losing the engineering substance. The report should explain what was delivered, what was difficult, and why the work mattered. A commit count is supporting evidence, not the report itself.

This skill is read-only. Do not modify product code, project documentation, Git history, branches, or user files while collecting evidence.

## Date Window

Use the following default when the user does not state a range:

- `end`: the most recent Sunday that has already occurred in the current local calendar week. On Monday through Saturday, this is the immediately preceding Sunday; on Sunday, it is today.
- `start`: the Sunday seven calendar days before `end`.
- Include both boundary dates through the end of `end` (23:59:59 local time).

Interpret the user's shorthand such as “本周日到上周日” as the completed Sunday-to-Sunday reporting week. State the resolved range once in the report header. Do not repeat dates in every workstream.

An explicit user range always wins, including phrases such as “8月9日到8月16日”, “上周”, “从某日到某日”, or an explicit author-date/commit-date instruction. If the wording has two materially different interpretations, ask one concise clarification before collecting data.

Use the local project timezone for calendar boundaries. Do not silently replace an explicit range with the current date.

## Identity And Git Scope

1. Resolve the author identity before counting. Prefer the name/email supplied by the user. If the user says “我的提交” without an identity, inspect `git config user.name`, `git config user.email`, and recent author names; ask only when multiple plausible identities would materially change the report.
2. Default to `--all` refs so work done on a relevant branch is not silently missed. Deduplicate by commit hash.
3. Use **author date** as the primary period filter because the report describes when the developer did the work. If the user explicitly says “提交时间” or “合入时间”, use committer date instead. When the two counts differ materially, mention the reason briefly in an evidence note.
4. Separate real work from Git bookkeeping. Do not present stash objects, merge bookkeeping, or replayed/cherry-picked duplicate patches as independent business outcomes. If they affect counts, explain them in one short note instead of putting them in the work list.
5. Do not use a raw commit total as a proxy for productivity. A single architectural change may span many commits, while a follow-up fix may be part of the same delivery.

## Safe Git Collection

Use Git commands that remain reliable in PowerShell and do not depend on decoding Chinese commit subjects during counting.

- Count or filter with hash/date-only output, `git rev-list --count`, or file redirection.
- Avoid assigning `git log` output containing `%s` Chinese subjects directly to a PowerShell variable when exact line counts matter; this can merge or drop output lines. If subjects are needed, redirect UTF-8 output to a file or collect hashes first and inspect subjects per commit.
- Keep the raw evidence outside the final report. Useful evidence includes commit hash, author/committer dates, subject, changed paths, insertion/deletion stats, and focused diffs.
- Inspect enough diffs and affected files to validate the outcome. Do not read hundreds of full diffs when path and subject clustering plus representative focused inspection can establish the same fact.

At minimum, verify:

- the resolved author identity;
- the inclusive date range and date basis;
- the complete matching commit set after hash deduplication;
- the main affected packages, applications, scripts, tests, and docs;
- any count discrepancy caused by refs, stash, branch duplicates, or date fields.

## Workstream Extraction

Cluster related commits by independently meaningful delivery, not by arbitrary commit boundaries. Preserve separate workstreams when they have different owners, risks, verification surfaces, or user-visible outcomes. Typical clusters include:

- architecture, ownership, lifecycle, or state-machine changes;
- protocol, API, SSE, transport, authentication, or tenant-isolation changes;
- user-facing interaction and session behavior;
- public component library work and page migrations;
- visual alignment across a coherent set of screens;
- build, test, QA, release, or developer-experience improvements;
- performance and cleanup with a clear engineering outcome.

When the user asks for a detailed workstream report, do not collapse all work into a few generic themes. Keep the independent items visible because the number of small protocol, UI, and reliability changes is itself useful context.

Merge pure documentation, governance, test-contract, and developer-instruction items into one “文档、治理与质量保障” item unless they represent a separate product delivery. Keep build engineering separate when it changes runtime, build speed, artifact behavior, or developer workflow.

Exclude stash records from the report body. Mention them only if the user asks for a reconciled commit count.

## Technical Detail Standard

For each workstream, retain the details that explain difficulty and value:

- what changed in plain language;
- which system boundary, state transition, protocol field, data owner, component contract, or build constraint was involved;
- why the change was non-trivial;
- the observable result or risk reduced;
- any unverified end-to-end behavior or remaining technical debt.

Translate implementation detail for a manager without deleting it. For example:

- “串行化异步 onMessage” becomes “保证 SSE 事件按到达顺序处理，避免消息乱序”；
- “Worker ownership guard” becomes “用门禁防止主线程和 Worker 重新形成两套会话数据源”；
- “tenant-scoped query keys” becomes “切换租户时同时隔离会话、实时连接和缓存，避免跨租户串数据”；
- “public component migration” becomes “将多个页面从内联控件迁移到公共组件，后续修复可以统一生效”。

Do not claim “显著提升”“彻底解决” or similar impact unless the code, tests, measurements, or runtime evidence support it. Use “减少风险”“统一约束”“为后续扩展提供基础” when that is what the evidence proves.

## Default Report Format

Return a paste-ready Chinese report with this shape:

```markdown
# [姓名] 周报（[起始日期]—[结束日期]）

## 本周概览

[用 3—5 句话说明本周最重要的交付主线、覆盖范围和总体价值。]

## 工作内容

### 1. [独立工作流名称]

[完成内容。]

[技术难点、风险或价值。]

### 2. [独立工作流名称]

[完成内容。]

[技术难点、风险或价值。]

...

## 风险与后续

[只列证据支持的未完成验收、技术债或下一步。没有则省略本节。]
```

Follow these presentation rules by default:

- Write in Chinese, with simple manager-readable headings and concrete technical detail.
- Do not include representative commit hashes, full commit lists, or file-by-file inventories unless requested.
- Do not put detailed dates on each item; put the reporting period in the title and use sequence or topic to organize the body.
- Do not force every item to carry a commit count. If counts are useful, put one short methodology note outside the main work list.
- Keep independent workstreams separate. Merge only the documentation/governance/testing items described above or items the user explicitly asks to merge.
- Avoid generic filler such as “加强了系统稳定性” without saying which failure mode or boundary was addressed.
- Prefer two short paragraphs per item: “完成了什么” followed by “难点/价值是什么”.
- End with risks or unverified areas rather than inventing a positive conclusion.

## Count Reconciliation Note

Only include a count section when the user asks about how many commits were made or when the evidence has a material discrepancy. Keep it short:

1. State the primary count and whether it uses author date or committer date.
2. Explain differences caused by all refs versus main, stash objects, replayed branch duplicates, or boundary dates.
3. Never treat duplicated branch patches or stash objects as additional independent deliveries.

If the user only asks for a report, omit this accounting detail and focus on delivered outcomes.

## Final Quality Check

Before answering, verify that:

- the date range in the title matches the requested/default rule;
- the author identity and date basis are not silently assumed when ambiguous;
- every meaningful commit cluster is represented or explicitly excluded;
- related follow-up commits are not inflated into multiple fake achievements;
- technical hard parts and unresolved risks remain visible;
- no commit hashes, detailed per-item dates, or raw command output slipped into the report by default;
- the result can be pasted into a weekly report without requiring the user to rewrite it.
