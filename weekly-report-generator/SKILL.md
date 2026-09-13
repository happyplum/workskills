---
name: weekly-report-generator
description: >-
  Generate a Chinese weekly work report from Git history and verified project evidence. Use this skill whenever the user asks for 周报、周工作总结、本周工作、提交汇报、迭代总结、工作量汇报, or wants to turn their commits into a leader-readable report. The default period is last Sunday through today, not a completed Sunday-to-Sunday week; if today is Monday–Saturday, do not snap the end date back to last Sunday. If the user gives an explicit date range, always use that range instead. Write professional written Chinese: not code-comment wording, and not a spoken walkthrough or diary. Item bodies must add a verified cause or mechanism, not restate the title. Style complaints (流水账, 不专业, 太啰嗦) change wording only, never merge independent workstreams. Do not dump commit hashes, detailed per-item dates, or raw Git history unless the user asks for them.
---

# Weekly Report Generator

## Purpose

Turn a developer's Git activity into a written weekly report a manager can paste without rewriting. The reader should learn what was delivered, why it mattered (verified cause or mechanism, not a restated title), and what remains open. A commit count is supporting evidence, not the report itself.

This skill is read-only. Do not modify product code, project documentation, Git history, branches, or user files while collecting evidence.

## Date Window

Default when the user does not state a range: **上周日到今天**. Do not wait for a completed Sunday-to-Sunday week, and do not force `end` onto a Sunday.

- `end`: today (current local calendar date), through 23:59:59 local time. Never snap `end` back to last Sunday just because today is Monday–Saturday.
- `start`: the most recent Sunday strictly before today. If today is Sunday, that is seven days ago, not today.
- Include both boundary dates.

Examples, assuming today in the local calendar:

- Today is Thursday 9月10日 → `9月6日`（上周日）— `9月10日`（今天）.
- Today is Sunday 9月13日 → `9月6日`（上周日）— `9月13日`（今天）.
- Wrong: today is Thursday 9月10日, but the report uses `8月30日`—`9月6日`. That is last Sunday to the Sunday before, which drops this week's work.

State the resolved range once in the report header. Do not repeat dates in every workstream.

An explicit user range always wins, including “8月9日到8月16日”, “上周”, or “从某日到某日”. Only then may the window be a full Sunday-to-Sunday or any other span. If the wording has two materially different interpretations, ask one concise clarification before collecting data.

Use the local project timezone for calendar boundaries. Do not silently replace an explicit range with the default, and do not silently replace the default with a completed week.

## Identity And Git Scope

1. Resolve the author identity before counting. Prefer the name/email supplied by the user. If the user says “我的提交” without an identity, inspect `git config user.name`, `git config user.email`, and recent author names; ask only when multiple plausible identities would materially change the report.
2. Default to `--all` refs so work done on a relevant branch is not silently missed. Deduplicate by commit hash.
3. Use **author date** as the primary period filter because the report describes when the developer did the work. If the user explicitly says “提交时间” or “合入时间”, use committer date instead. When the two counts differ materially, mention the reason briefly in an evidence note.
4. Separate real work from Git bookkeeping. Do not present stash objects, merge bookkeeping, or replayed/cherry-picked duplicate patches as independent business outcomes. If they affect counts, explain them in one short note instead of putting them in the work list.
5. Do not use a raw commit total as a proxy for productivity. A single architectural change may span many commits, while a follow-up fix may be part of the same delivery.

## Safe Git Collection

Use Git commands that remain reliable in PowerShell and do not depend on decoding Chinese commit subjects during counting.

- Count or filter with hash/date-only output, `git rev-list --count`, or file redirection.
- Avoid assigning `git log` output containing `%s` Chinese subjects directly to a PowerShell variable when exact line counts matter; this can merge or drop output lines. Collect hashes first, then inspect subjects per commit; do not create evidence files inside the repository.
- Keep the raw evidence outside the final report. Useful evidence includes commit hash, author/committer dates, subject, changed paths, insertion/deletion stats, and focused diffs.
- Inspect enough diffs and affected files to validate the outcome. Do not read hundreds of full diffs when path and subject clustering plus representative focused inspection can establish the same fact.

At minimum, verify:

- the resolved author identity;
- the inclusive date range and date basis;
- the complete matching commit set after hash deduplication;
- the main affected packages, applications, scripts, tests, and docs;
- any count discrepancy caused by refs, stash, branch duplicates, or date fields.

## Workstream Extraction

Cluster Git commits by independently meaningful **delivery** first, then count the items. Never pick a target count and merge backwards to hit it.

**MUST stay separate** when either is true:

- the main delivery objects differ, and each can stand as a complete manager-facing item (引导 vs 工作面板 vs 插件菜单);
- even with the same object, the intent, acceptance result, or release/rollback boundary is independent.

**MAY merge** only when clusters share one main object, one intent, and one acceptance result. Implementation, styling, state persistence, tests, and verification for that same delivery stay inside it. Do not turn those into a process diary.

Same directory, same day, same author, same product area, a heading that already uses 「；」, or a wish to keep 7 items, is not a merge reason. If the user asked to keep a count, still do not merge independent workstreams; keep the count only when natural clustering already matches it.

**Style feedback does not recluster.** If the user says 流水账、不专业、太啰嗦、废话, or similar, rewrite wording and cut filler only. Do not merge, split, reorder, or drop workstreams unless the user names a specific item to delete or merge, or new evidence shows an item is not independent. Deleting one named item (for example 「第10条去掉」) removes only that item.

Pure documentation, governance, test-contract, and developer-instruction changes belong with the delivery they support. If one is itself an independent manager-facing delivery, keep it separate and name that delivery, for example 「新增界面对齐规格」, not the bucket 「文档、治理与质量保障」. Keep build engineering separate when it changes runtime, build speed, artifacts, or developer workflow.

Exclude stash records from the report body. Mention them only if the user asks for a reconciled commit count.

## Leader Voice（书面汇报，不是注释，也不是流水账）

周报是给领导看的书面工作汇报。不是代码注释的中文版，也不是把操作过程讲成故事。先识别本周实际交付，再写标题和正文：

- 标题回答「本周交付了什么」，用「新增 / 调整 / 补齐 / 修复 + 主要交付对象」。必要时补范围，但不要只写模块名。
- 正文必须补充标题里没有的关键信息，禁止用同义句复述标题。修复类优先写「已验证的主因或关键机制 + 直接结果」；新增、调整、补齐类写「关键能力 + 业务结果」。可按账号记住、不跟随滚动、不再遮挡，只能写在正文，不能代替交付当标题。证据不足时写已验证机制，不编造唯一根因。仍禁止「以前…现在…」叙事。

交稿前四道检验：

1. 读完一句，能否直接回答「做成了什么、结果是什么」。只能回答「改了哪个函数」，是注释话。
2. 读完一句，是否像在演示或复盘过程。出现「以前会…这次改成…就不会…」的小故事，或「闪一下 / 被带走 / 糊成一块」这类口语，是流水账。
3. 读完标题，能否直接回答「这周做了哪一件交付」。标题写的是性状或副作用（可记住、不再打断、不再遮挡），而不是那件交付，是交付性状化。
4. 删掉标题后，正文是否还剩新事实。只剩「修复了…问题」「已调整为…」这类同义复述，是空转，整句重写。

四种都要整句重写。去的是腔，不是技术。协议、所有权、租户隔离、发布回滚都要在，用书面结果说。空话也不行：「优化了体验」「加强了稳定性」没有具体结果，等于没写。复述标题也等于没写。

### 四种写法

同一件事，差在句子骨架，不在用了多少术语。

| 腔调 | 例子 | 问题 |
|---|---|---|
| 注释话 | 将 Work panel 改为 floating overlay，防止 scroll 带走 | 内部手段当句子，像提交说明 |
| 流水账 | 工作面板改成浮在对话上，滚动对话时不会被带走 | 在讲发生了什么过程，像演示稿 |
| 空转 | 标题「修复长会话滚动定位」；正文「修复了长会话滚动定位不准的问题」 | 正文复述标题，没有新事实 |
| 书面汇报 | 标题「修复长会话滚动定位」；正文「底部叠了两层较大留白，未渲染内容又按估算高度占位，滚动高度被撑高，定位和跳转都不准」 | 标题命名交付，正文补标题没有的主因 |
| 交付性状化 | 工作模式引导可记住 | 把附带性状当标题，看不出这周做的是「新增工作模式引导」 |

再举几组，正例一律用书面汇报，不要写成「以前…现在…」：

**反例（空转）：** 标题「修复长会话滚动定位」；正文「修复了长会话滚动定位不准的问题。」  
**正例：** 标题「修复长会话滚动定位」；正文「底部叠了两层较大留白，未渲染内容又按估算高度占位，滚动高度被撑高，定位和跳转都不准。现已只保留输入区实测高度作为底部空间。」

**反例（注释）：** 串行化异步 onMessage → 保证 SSE 按到达顺序处理，避免消息乱序  
**反例（流水账）：** 流式对话有时会后到的先显示。这次改成按到达顺序出字，对话不会跳着刷。  
**正例：** 标题「修复流式消息乱序」；正文「展示顺序未跟到达顺序对齐，后到的会先显示。现已按到达顺序出字。」

**反例（注释）：** Worker ownership guard → 用门禁防止主线程和 Worker 形成两套数据源  
**反例（流水账）：** 主界面和后台以前会各记一份会话，改着改着就对不上。这次规定只由一方持有。  
**正例：** 标题「调整会话状态持有方式」；正文「会话改为单侧持有，主界面与后台不再各记一份。」

**反例（注释）：** 实现三轴响应式抽屉：独立状态模型 + 宽度同步  
**反例（流水账）：** 侧栏三种宽度共用一套界面，以前滚动条和菜单会互相挡。这次分开处理后菜单不再被挡住。  
**正例：** 标题「修复侧栏菜单遮挡」；正文「折叠、展开和抽屉三种宽度共用一套菜单层，层级叠在一起会互相挡住。现已按宽度分开处理。」

**反例（交付性状化）：** 工作模式引导可记住  
**反例（合并）：** 工作模式引导可记住；调整工作面板样式为浮动，不跟随对话滚动  
**正例：** 拆成两条。标题「新增工作模式引导」，正文写按账号记录已查看状态。标题「调整工作面板为浮动布局」，正文写面板改为浮层、不占用对话滚动区域。引导展示和按账号记住同属新增引导，可写在一条；工作面板是另一交付对象，必须分开。插件菜单与这两者都不同，也不要并进同一条。

产品名、用户能看见的能力名可以保留（Casdoor、Electron、Ultma）。函数名、文件名、内部类型名、配置键不要进正文。

### 流水账从哪来

为了去掉注释腔，容易矫枉过正，把每条都写成「以前怎样、现在怎样」的口头对比。领导看起来像流水账，不专业。典型来源：

- 每条都用「以前会…现在…这次把…」开场，像在复盘演示，不像在交工作。
- 生活化比喻：闪一下、盖一层、被带走、糊成一块、打架、跳着刷、挤换行。
- 操作说明书口吻：点进去、不会自动发出去、还要再点一遍。
- 安抚解释：这是预期，不是丢了进度。

对比只在对比本身就是结果时写一句，不要当作默认句式。

### 用词和句子

- 默认句式按交付类型选：修复写「已验证主因或关键机制 + 直接结果」；新增、调整、补齐写「关键能力 + 业务结果」。不要用标题同义句占位，也不要每条都讲故事。证据指向多项机制时如实写，不编造单一根因。
- 「实现了 / 新增了 / 将 X 改为 Y」后面接内部模块、函数、配置键，是注释话。接用户能感知的入口或能力（独立登录页、创建项目弹窗）可以保留。
- 「保证 / 避免 / 防止 / 用于 / 以便」不要当主句；结果写成性状，如「不跟随对话滚动」，不要写成「防止滚动带走」。
- 「补齐 / 收敛 / 对齐 / 沉淀契约」不能单独当结果，要写出对象变成了什么。
- 标题命名交付，不写裸模块名，也不写结果口号。反例：「侧栏系统：三态响应式与视觉基线」（模块名）、「工作模式引导可记住」（性状）、「新增工作模式引导；调整工作面板为浮动布局」（两件事）。正例：「新增工作模式引导」「调整工作面板为浮动布局」。
- 「可记住 / 不再打断 / 不再遮挡 / 选择空间后再进入聊天」写在正文。标题用新增、调整、补齐、修复 + 对象。「新增独立登录页」可以当标题；「登录改为独立页面，选择空间后再进入聊天」是把结果塞进了标题。
- 一条标题只写一件交付。不要用分号或顿号把两件交付拼成一条。条目数量由独立交付决定，不强制固定。
- 默认用书面短段落，不用 changelog 短横清单，也不用口语连写。用户要求要点时，每条仍是书面句，括号里不塞符号名。
- 未完成验收写成「…尚未完成视觉走查 / 待上游合并后统一替换」，不要写成「还要再点一遍，避免有人不知道怎么回来」。

起草后默读：像是在交书面周报，还是在给领导演示，或在给 diff 写备注。后两种都整句重写。

## Technical Detail Standard

This is an evidence pool for clustering and drafting, not a body checklist. Each item picks only the highest-density facts that explain the delivery. Prior wrong behavior stays only when it is needed to state the verified cause; do not auto-expand it into a before/after story.

From the pool, select as needed:

- the concrete failure mode, limitation, or verified cause;
- which boundary was involved: session ownership, protocol field, tenant isolation, component contract, build/release, or similar;
- why that boundary was easy to get wrong, only if it is the main fact;
- the observable result now, or the risk that is now smaller;
- any unverified end-to-end behavior or remaining debt, attached to that same item.

Do not claim “显著提升”“彻底解决” or similar impact unless the code, tests, measurements, or runtime evidence support it. State only the concrete observable result or remaining risk that the evidence proves.

## Default Report Format

Return a paste-ready Chinese report with this shape:

```markdown
# [姓名] 周报（[起始日期]—[结束日期]）

## 本周概览

[用 3—5 句书面句说明本周主线、覆盖范围和做成后的结果。不要罗列模块名，不要讲过程故事。]

## 工作内容

### 1. [新增 / 调整 / 补齐 / 修复 + 交付对象]

[2—4 句书面句：标题里没有的主因、机制或关键能力，再写直接结果。修复优先写已验证原因；不要用「以前…现在…」当骨架，也不要用标题同义句占位。附带性状（可记住、不跟随滚动）写在正文。]

[未完成验收或遗留问题用 1 句书面句附在同条。没有则不写。]

### 2. [新增 / 调整 / 补齐 / 修复 + 交付对象]

[同上]

...
```

Follow these presentation rules by default:

- Write in professional written Chinese. Not spoken walkthrough, not changelog comments.
- Headings name one delivery in written register, not a module name, not a side-effect trait, and not two deliveries joined by a semicolon.
- Do not include representative commit hashes, full commit lists, file-by-file inventories, function names, or internal type names unless requested.
- Do not put detailed dates on each item; put the reporting period in the title and use sequence or topic to organize the body.
- Do not force every item to carry a commit count. If counts are useful, put one short methodology note outside the main work list.
- Keep independent workstreams separate per the MUST/MAY merge rules above. Never merge two deliveries to hold a previous item count, and never merge them to shorten a “流水账” rewrite.
- Prefer deleting title restatement, capability enumerations, unrelated implementation detail, and non-acceptance asides. Do not shorten the report by merging independent deliveries.
- Avoid generic filler such as “加强了系统稳定性” without saying which failure mode or boundary was addressed.
- Put unfinished verification or leftover debt in the same work item that caused it. Do not add a separate 「风险与后续」 section. Do not invent a positive wrap-up paragraph either.

## Count Reconciliation Note

Only include a count section when the user asks about how many commits were made or when the evidence has a material discrepancy. Keep it short:

1. State the primary count and whether it uses author date or committer date.
2. Explain differences caused by all refs versus main, stash objects, replayed branch duplicates, or boundary dates.
3. Never treat duplicated branch patches or stash objects as additional independent deliveries.

If the user only asks for a report, omit this accounting detail and focus on delivered outcomes.

## Final Quality Check

Before answering, verify that:

- the date range in the title matches the requested range, or the default last-Sunday-through-today rule; if the user did not specify dates, `end` is today and is not a prior Sunday;
- the author identity and date basis are not silently assumed when ambiguous;
- every meaningful commit cluster is represented or explicitly excluded;
- related follow-up commits are not inflated into multiple fake achievements;
- technical hard parts and unresolved risks remain visible inside the relevant work item, written as consequences rather than diagnostics, and are not collected into a separate 「风险与后续」 section;
- no commit hashes, detailed per-item dates, raw command output, function names, or internal type names slipped into the report by default;
- no sentence is 注释话: scan for parenthesized symbol names, module dumps, 「保证…避免…」, and 「实现了 / 新增了 / 将 X 改为 Y」 whose object is an internal module rather than a user-facing capability; rewrite those sentences before delivery;
- no sentence is 流水账: scan for default 「以前…现在…这次…」 skeletons, oral images such as 「闪一下 / 被带走 / 糊成一块 / 打架 / 跳着刷」, and demo phrasing such as 「点进去 / 再点一遍 / 这是预期」; rewrite those sentences, but do not merge items to do it;
- no sentence is 空转: cover the title and check whether the body still has a verified cause, mechanism, or capability the title does not already name; 「修复了…问题」「已调整为…」 that only repeat the heading must be rewritten;
- style-only user feedback did not change the workstream set, order, or count unless the user named a specific item to delete or merge;
- each heading names one delivery with 「新增 / 调整 / 补齐 / 修复 + 对象」 (「新增工作模式引导」), not a trait (「工作模式引导可记住」), not a result slogan (「选择空间后再进入聊天」), and not two deliveries joined by 「；」;
- a manager who does not know the repo can understand each item without asking what a module does, and the wording would pass as a written weekly report rather than a walkthrough;
- the result can be pasted into a weekly report without requiring the user to rewrite it.
