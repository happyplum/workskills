#!/usr/bin/env node
// scorecard.mjs v1.1 — 执行会话树的可证伪度量（D-015/D-017）
//
// 用法（PowerShell）：
//   node scorecard.mjs --root ses_fe4fbef3                  # 会话树总账 + 度量摘要
//   node scorecard.mjs --root ses_xxx --gap 120             # 间隙阈值秒数（默认 60）
//   node scorecard.mjs --root ses_xxx --prompts <dir>       # prompt 目录（默认 ~/.config/opencode/prompts）
//   node scorecard.mjs --root ses_xxx --expect-hash <hex>   # 与 ledger 盖印的派发时刻 promptHash 对账
//
// v1.1 度量项（相对 v1 的修正，对应双审 F11）：
//   1. 同回合突发 fan-out：按 message_id 分组 task 派发，报告 max_burst 与 burst≥2 次数
//      （parallel_ratio=bg=true 占比 ≠ C1 的同回合并发派发，两者并列输出）
//   2. oracle 复审模式归因：按 dispatch prompt 正则 INITIAL/DELTA/ACCEPTANCE_REVIEW_V1 分类计数
//   3. baseline 顺序断言（启发式）：树内最早的基线类命令（plan-linter baseline / verify / 全量测试）
//      是否早于首个 task 派发（BASELINE_FIRST，D-013 基线预验）
//   4. per-agent 成本表
//   5. promptHash 标注「度量时刻值」，--expect-hash 对账派发时刻盖印值（执行后改过 prompt 即 MISMATCH）
//   6. gap 分角色：父会话（协调者）与子会话分开统计——父高 gap=健康并行信号，子高 gap=stall 信号
//
// 语义注意：dur = time_updated-time_created，续用（task_id 复用）会拉长会话跨度；
// gap = 会话内相邻 part 间隔，含续用之间的等待。同口径前后对照有效，绝时值不代表墙钟占用。
// 只读，DB 一律 readOnly 打开。

import { DatabaseSync } from 'node:sqlite'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'

const args = process.argv.slice(2)
const opt = (name, dflt) => {
  const i = args.indexOf(`--${name}`)
  return i >= 0 ? args[i + 1] : dflt
}
const rootPrefix = opt('root', null)
const dbPath = opt('db', join(homedir(), '.local', 'share', 'opencode', 'opencode.db'))
const promptsDir = opt('prompts', join(homedir(), '.config', 'opencode', 'prompts'))
const gapThresholdMs = Number(opt('gap', 60)) * 1000
const expectHash = opt('expect-hash', null)

if (!rootPrefix) {
  console.error('usage: node scorecard.mjs --root <session-id-prefix> [--gap seconds] [--db path] [--prompts dir] [--expect-hash hex]')
  process.exit(1)
}

function promptHash(dir) {
  if (!existsSync(dir)) return 'unavailable'
  const files = []
  for (const f of readdirSync(dir)) if (f.endsWith('.md')) files.push(join(dir, f))
  const rt = join(dir, 'runtime', 'AGENTS.md')
  if (existsSync(rt)) files.push(rt)
  files.sort()
  const h = createHash('sha256')
  for (const f of files) h.update(f).update('\0').update(readFileSync(f)).update('\0')
  return h.digest('hex').slice(0, 16)
}

const db = new DatabaseSync(dbPath, { readOnly: true })

const roots = db.prepare(`SELECT id FROM session WHERE id LIKE ?`).all(`${rootPrefix}%`)
if (roots.length !== 1) {
  console.error(`--root prefix '${rootPrefix}' matched ${roots.length} sessions`)
  process.exit(1)
}

const all = db.prepare(`SELECT id, parent_id, agent, cost, tokens_input, tokens_output, tokens_cache_read, time_created, time_updated, title FROM session`).all()
const byParent = new Map()
for (const r of all) {
  if (!r.parent_id) continue
  if (!byParent.has(r.parent_id)) byParent.set(r.parent_id, [])
  byParent.get(r.parent_id).push(r)
}
const tree = []
const walk = (id, depth) => {
  const s = all.find((r) => r.id === id)
  if (!s) return
  tree.push({ ...s, depth })
  for (const c of (byParent.get(id) || [])) walk(c.id, depth + 1)
}
walk(roots[0].id, 0)

const partStmt = db.prepare(`
  SELECT message_id, time_created, time_updated,
         json_extract(data, '$.type') as type,
         json_extract(data, '$.tool') as tool,
         json_extract(data, '$.state.input.run_in_background') as bg,
         json_extract(data, '$.state.input.subagent_type') as stype,
         json_extract(data, '$.state.input.command') as cmd,
         substr(json_extract(data, '$.state.input.prompt'), 1, 4000) as prompt
  FROM part WHERE session_id = ? ORDER BY time_created
`)

let totCost = 0, totIn = 0, totOut = 0, totCache = 0
let totGapMs = 0, parentGapMs = 0, childGapMs = 0
let totDispatch = 0, totBg = 0
const bursts = new Map() // message_id -> dispatch count
const reviewModes = { initial: 0, delta: 0, legacy: 0 }
const perAgent = new Map() // agent -> {count, cost, inK}
let earliestBaselineMs = null
let earliestDispatchMs = null
const gapBuckets = { '1-5min': 0, '5-30min': 0, '>30min': 0 }
const fmt = (ms) => new Date(ms).toLocaleString('zh-CN', { hour12: false, timeZone: 'Asia/Shanghai' })

const hashNow = promptHash(promptsDir)
let gitRev = 'unavailable'
try {
  gitRev = execFileSync('git', ['-C', promptsDir, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).trim()
} catch { /* prompts 目录非 git 仓时不可用 */ }
console.log(`root=${roots[0].id} promptHash=${hashNow}（度量时刻值） promptGitRev=${gitRev}（与 ledger 的 prompt_rev 事件对账） generated=${fmt(Date.now())}`)
if (expectHash) console.log(`expect-hash=${expectHash} => ${expectHash === hashNow ? 'MATCH' : 'MISMATCH（prompt 在执行后发生过变化，行为不能归因于 ledger 盖印版本）'}`)
console.log('---')

for (const s of tree) {
  const parts = partStmt.all(s.id)
  let gapMs = 0, dispatches = 0, bg = 0
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i]
    if (p.type === 'tool' && (p.tool === 'task' || p.tool === 'call_omo_agent')) {
      dispatches++
      if (p.bg === 1 || p.bg === true || p.bg === 'true') bg++
      bursts.set(p.message_id, (bursts.get(p.message_id) || 0) + 1)
      if (!earliestDispatchMs || p.time_created < earliestDispatchMs) earliestDispatchMs = p.time_created
      if (p.stype === 'oracle' || /oracle/i.test(p.stype || '')) {
        const pr = p.prompt || ''
        if (/DELTA/.test(pr) && !/INITIAL/.test(pr)) reviewModes.delta++
        else if (/ACCEPTANCE_REVIEW_V1|INITIAL/.test(pr)) reviewModes.initial++
        else reviewModes.legacy++
      }
    }
    if (p.type === 'tool' && p.tool === 'bash' && p.cmd && /plan-linter.*baseline|verify|pnpm\s+(run\s+)?(test|verify|-r\s+verify)|全量|整链/i.test(p.cmd)) {
      if (!earliestBaselineMs || p.time_created < earliestBaselineMs) earliestBaselineMs = p.time_created
    }
    if (i > 0) {
      const g = p.time_created - parts[i - 1].time_updated
      if (g > gapThresholdMs) {
        gapMs += g
        const m = g / 60000
        if (m < 5) gapBuckets['1-5min']++
        else if (m < 30) gapBuckets['5-30min']++
        else gapBuckets['>30min']++
      }
    }
  }
  if (s.depth === 0) parentGapMs += gapMs; else childGapMs += gapMs
  const durMin = ((s.time_updated - s.time_created) / 60000).toFixed(0)
  const gapMin = (gapMs / 60000).toFixed(0)
  const title = (s.title || '').replace(/\s+/g, ' ').slice(0, 40)
  console.log(`${'  '.repeat(s.depth)}${s.id.slice(0, 14)} agent=${s.agent || '-'} dur=${durMin}min gap=${gapMin}min disp=${dispatches}(bg=${bg}) cost=$${(s.cost || 0).toFixed(2)} | ${title}`)
  totCost += s.cost || 0; totIn += s.tokens_input || 0; totOut += s.tokens_output || 0; totCache += s.tokens_cache_read || 0
  totGapMs += gapMs; totDispatch += dispatches; totBg += bg
  const a = s.agent || '-'
  if (!perAgent.has(a)) perAgent.set(a, { count: 0, cost: 0, inK: 0 })
  const pa = perAgent.get(a)
  pa.count++; pa.cost += s.cost || 0; pa.inK += (s.tokens_input || 0) / 1000
}

const wallMin = tree.length ? ((Math.max(...tree.map((s) => s.time_updated)) - Math.min(...tree.map((s) => s.time_created))) / 60000).toFixed(0) : 0
const parallelRatio = totDispatch > 0 ? ((totBg / totDispatch) * 100).toFixed(0) : 'n/a'
const burstSizes = [...bursts.values()]
const maxBurst = burstSizes.length ? Math.max(...burstSizes) : 0
const burstMulti = burstSizes.filter((n) => n >= 2).length
const oracleTotal = reviewModes.initial + reviewModes.delta + reviewModes.legacy
const baselineFirst = !earliestBaselineMs ? 'absent（树内未见基线预验/verify 类命令）'
  : !earliestDispatchMs ? 'n/a（无 task 派发）'
  : earliestBaselineMs < earliestDispatchMs ? 'yes' : 'NO（基线命令晚于首个 task 派发，违反 D-013）'

console.log('---')
console.log('SCORECARD v1.1')
console.log(`sessions=${tree.length} wall=${wallMin}min activeSum=${tree.reduce((a, s) => a + (s.time_updated - s.time_created), 0) / 60000 | 0}min`)
console.log(`gap_total=${(totGapMs / 60000).toFixed(0)}min | parent=${(parentGapMs / 60000).toFixed(0)}min（高=健康并行信号） children=${(childGapMs / 60000).toFixed(0)}min（高=stall 信号） buckets: 1-5min=${gapBuckets['1-5min']} 5-30min=${gapBuckets['5-30min']} >30min=${gapBuckets['>30min']}`)
console.log(`dispatches=${totDispatch} background=${totBg} parallel_ratio=${parallelRatio}% | fanout: max_burst=${maxBurst} bursts>=2:${burstMulti}（C1 同回合并发度量）`)
console.log(`oracle_reviews=${oracleTotal} initial=${reviewModes.initial} delta=${reviewModes.delta} legacy=${reviewModes.legacy}`)
console.log(`baseline_first=${baselineFirst}`)
console.log('per-agent:')
for (const [a, pa] of [...perAgent.entries()].sort((x, y) => y[1].cost - x[1].cost)) {
  console.log(`  ${a}: sessions=${pa.count} cost=$${pa.cost.toFixed(2)} input=${pa.inK.toFixed(0)}K`)
}
console.log(`cost_total=$${totCost.toFixed(2)} in=${(totIn / 1e6).toFixed(1)}M out=${(totOut / 1e6).toFixed(0)}K cacheRead=${(totCache / 1e6).toFixed(0)}M`)
