/**
 * query-sessions.mjs — OpenCode 会话检索 / 成本取证 / 父子树重建
 *
 * .SYNOPSIS
 *   只读查询 opencode.db 的 session 表：按关键词/时间窗检索会话、按根会话重建
 *   父子树（parent_id 递归）、汇总成本与 token 体量。用于「这次执行烧了多少钱/
 *   多长时间/派了哪些子代理」类审计，也用于按标题或工作目录定位目标会话。
 *
 * .USAGE (PowerShell)
 *   node "<skill-dir>/scripts/query-sessions.mjs" --match webpath --since 2026-08-19
 *   node "<skill-dir>/scripts/query-sessions.mjs" --root ses_xxxxxxxx
 *   node "<skill-dir>/scripts/query-sessions.mjs" --match remediate --db D:\path\opencode.db
 *
 * .PARAMETERS
 *   --match <substr>   title 或 directory 包含子串（LIKE %..%，大小写不敏感）
 *   --root  <ses_...>  树模式：输出该会话及全部后代（parent_id 递归，含缩进）
 *   --since <date>     起始时间（默认 48 小时前），如 2026-08-19 或 2026-08-19T23:00
 *   --db    <path>     覆盖默认 DB 路径
 *
 * .NOTES
 *   - 始终 readOnly 打开；DB 可能数十 GB，禁止 VACUUM/写操作。
 *   - cost 列仅按量计费模型有值；订阅/免费模型 cost=0 但 token 计数真实——
 *     成本审计时不得把 $0 当作零消耗，cacheRead 才是体量主力。
 *   - 依赖 node:sqlite（Node 22+ 内置，需 --experimental-sqlite 或 Node 23+）。
 */

import { DatabaseSync } from 'node:sqlite'
import { homedir } from 'node:os'
import { join } from 'node:path'

const args = process.argv.slice(2)
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`)
  return i >= 0 ? args[i + 1] : def
}

const dbPath = opt('db', join(homedir(), '.local', 'share', 'opencode', 'opencode.db'))
const match = opt('match', null)
const root = opt('root', null)
const sinceRaw = opt('since', null)
const since = sinceRaw ? new Date(sinceRaw).getTime() : Date.now() - 48 * 3600 * 1000

const db = new DatabaseSync(dbPath, { readOnly: true })
const COLS = `id, parent_id, title, agent, model, cost,
  tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write,
  time_created, time_updated`

const fmtTime = (ms) => new Date(ms).toLocaleString('zh-CN', { hour12: false, timeZone: 'Asia/Shanghai' })
const fmtTok = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(0)}K` : `${n}`)

function line(r, indent = '') {
  const durMin = ((r.time_updated - r.time_created) / 60000).toFixed(0)
  const title = (r.title || '').replace(/\s+/g, ' ').slice(0, 55)
  const cost = r.cost ? `$${r.cost.toFixed(2)}` : '$0*'
  return `${indent}${r.id} agent=${r.agent || '-'} cost=${cost} in=${fmtTok(r.tokens_input)} out=${fmtTok(r.tokens_output)} cacheR=${fmtTok(r.tokens_cache_read)} dur=${durMin}min ${fmtTime(r.time_created)} | ${title}`
}

function totals(rows) {
  const t = rows.reduce((a, r) => ({
    cost: a.cost + (r.cost || 0), inp: a.inp + r.tokens_input, out: a.out + r.tokens_output,
    reason: a.reason + r.tokens_reasoning, cacheR: a.cacheR + r.tokens_cache_read,
  }), { cost: 0, inp: 0, out: 0, reason: 0, cacheR: 0 })
  return `TOTAL sessions=${rows.length} cost=$${t.cost.toFixed(2)} in=${fmtTok(t.inp)} out=${fmtTok(t.out)} reason=${fmtTok(t.reason)} cacheRead=${fmtTok(t.cacheR)}  (* $0 = 订阅/未计费模型, token 消耗仍然真实)`
}

if (root) {
  const roots = db.prepare(`SELECT id FROM session WHERE id LIKE ?`).all(`${root}%`)
  if (roots.length !== 1) {
    console.error(`--root prefix '${root}' matched ${roots.length} sessions`)
    process.exit(1)
  }
  const rootId = roots[0].id
  const all = db.prepare(`SELECT ${COLS} FROM session ORDER BY time_created`).all()
  const byParent = new Map()
  for (const r of all) {
    if (!r.parent_id) continue
    if (!byParent.has(r.parent_id)) byParent.set(r.parent_id, [])
    byParent.get(r.parent_id).push(r)
  }
  const picked = []
  const walk = (id, depth) => {
    const node = all.find((r) => r.id === id)
    if (!node) return
    picked.push(node)
    console.log(line(node, '  '.repeat(depth)))
    for (const child of byParent.get(id) || []) walk(child.id, depth + 1)
  }
  walk(rootId, 0)
  console.log(totals(picked))
} else {
  const where = match
    ? `WHERE time_created > @since AND (title LIKE @m OR directory LIKE @m)`
    : `WHERE time_created > @since`
  const rows = db.prepare(`SELECT ${COLS} FROM session ${where} ORDER BY time_created`)
    .all({ since, ...(match ? { m: `%${match}%` } : {}) })
  for (const r of rows) console.log(line(r, r.parent_id ? '  ' : ''))
  console.log(totals(rows))
}
