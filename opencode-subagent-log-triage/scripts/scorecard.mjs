#!/usr/bin/env node
// scorecard.mjs — 执行会话树的可证伪度量（D-015）
//
// 用法（PowerShell）：
//   node scorecard.mjs --root ses_fe4fbef3            # 会话树总账 + 度量摘要
//   node scorecard.mjs --root ses_xxx --gap 120       # 间隙阈值秒数（默认 60）
//   node scorecard.mjs --root ses_xxx --prompts <dir> # prompt 目录（默认 ~/.config/opencode/prompts）
//
// 度量项：并行派发率（run_in_background=true 占比）、gap 直方图与总停顿、
// oracle 复审次数与成本、成本/token 总账、prompt 文件 hash（归因标签）。
// 语义注意：dur = time_updated-time_created，续用（task_id 复用）会拉长会话跨度；
// gap = 会话内相邻 part 间隔，含续用之间的等待。同口径前后对照有效，绝时值不代表墙钟占用。
// 只读，DB 一律 readOnly 打开。

import { DatabaseSync } from 'node:sqlite'
import { createHash } from 'node:crypto'
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

if (!rootPrefix) {
  console.error('usage: node scorecard.mjs --root <session-id-prefix> [--gap seconds] [--db path] [--prompts dir]')
  process.exit(1)
}

// prompt 文件 hash（归因标签）：治理 prompt 内容变则 hash 变
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

// 重建会话树
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
  SELECT time_created, time_updated,
         json_extract(data, '$.type') as type,
         json_extract(data, '$.tool') as tool,
         json_extract(data, '$.state.input.run_in_background') as bg
  FROM part WHERE session_id = ? ORDER BY time_created
`)

let totCost = 0, totIn = 0, totOut = 0, totCache = 0
let totGapMs = 0, totDispatch = 0, totBg = 0
let oracleCount = 0, oracleCost = 0, oracleIn = 0
const gapBuckets = { '1-5min': 0, '5-30min': 0, '>30min': 0 }
const fmt = (ms) => new Date(ms).toLocaleString('zh-CN', { hour12: false, timeZone: 'Asia/Shanghai' })

console.log(`root=${roots[0].id} promptHash=${promptHash(promptsDir)} generated=${fmt(Date.now())}`)
console.log('---')

for (const s of tree) {
  const parts = partStmt.all(s.id)
  let gapMs = 0, dispatches = 0, bg = 0
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i]
    if (p.type === 'tool' && (p.tool === 'task' || p.tool === 'call_omo_agent')) {
      dispatches++
      if (p.bg === 1 || p.bg === true || p.bg === 'true') bg++
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
  const durMin = ((s.time_updated - s.time_created) / 60000).toFixed(0)
  const gapMin = (gapMs / 60000).toFixed(0)
  const title = (s.title || '').replace(/\s+/g, ' ').slice(0, 40)
  console.log(`${'  '.repeat(s.depth)}${s.id.slice(0, 14)} agent=${s.agent || '-'} dur=${durMin}min gap=${gapMin}min disp=${dispatches}(bg=${bg}) cost=$${(s.cost || 0).toFixed(2)} | ${title}`)
  totCost += s.cost || 0; totIn += s.tokens_input || 0; totOut += s.tokens_output || 0; totCache += s.tokens_cache_read || 0
  totGapMs += gapMs; totDispatch += dispatches; totBg += bg
  if (s.agent === 'oracle') { oracleCount++; oracleCost += s.cost || 0; oracleIn += s.tokens_input || 0 }
}

const wallMin = tree.length ? ((Math.max(...tree.map((s) => s.time_updated)) - Math.min(...tree.map((s) => s.time_created))) / 60000).toFixed(0) : 0
const gapMinTotal = (totGapMs / 60000).toFixed(0)
const gapShare = wallMin > 0 ? ((totGapMs / 60000 / wallMin) * 100).toFixed(0) : 0
const parallelRatio = totDispatch > 0 ? ((totBg / totDispatch) * 100).toFixed(0) : 'n/a'

console.log('---')
console.log('SCORECARD')
console.log(`sessions=${tree.length} wall=${wallMin}min activeSum=${tree.reduce((a, s) => a + (s.time_updated - s.time_created), 0) / 60000 | 0}min`)
console.log(`gap_total=${gapMinTotal}min (${gapShare}% of wall) buckets: 1-5min=${gapBuckets['1-5min']} 5-30min=${gapBuckets['5-30min']} >30min=${gapBuckets['>30min']}`)
console.log(`dispatches=${totDispatch} background=${totBg} parallel_ratio=${parallelRatio}%`)
console.log(`oracle_reviews=${oracleCount} cost=$${oracleCost.toFixed(2)} input=${(oracleIn / 1000).toFixed(0)}K`)
console.log(`cost_total=$${totCost.toFixed(2)} in=${(totIn / 1e6).toFixed(1)}M out=${(totOut / 1000).toFixed(0)}K cacheRead=${(totCache / 1e6).toFixed(0)}M`)
