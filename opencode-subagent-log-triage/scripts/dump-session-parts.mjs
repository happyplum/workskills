/**
 * dump-session-parts.mjs — 导出某会话的工具 part 时间线（卡住取证核心）
 *
 * .SYNOPSIS
 *   只读读取 opencode.db 的 part 表，按时间列出目标会话的工具调用 part：
 *   状态、exit code、工具名、描述、命令、最后更新时间。用于判断「工具仍在跑
 *   还是仅存储陈旧」，替代手写 json_extract SQL。
 *
 * .USAGE (PowerShell)
 *   node "<skill-dir>/scripts/dump-session-parts.mjs" ses_xxxxxxxx
 *   node "<skill-dir>/scripts/dump-session-parts.mjs" ses_xxxxxxxx --stuck
 *   node "<skill-dir>/scripts/dump-session-parts.mjs" ses_xxxxxxxx --tool bash --last 20
 *
 * .PARAMETERS
 *   <sessionId>   位置参数，支持唯一前缀（如 ses_fe4fbef3）
 *   --stuck       只看未闭合 part（status 非 completed/error）
 *   --tool <name> 只看指定工具
 *   --last <N>    只输出最后 N 条
 *   --db <path>   覆盖默认 DB 路径
 *
 * .NOTES
 *   - 始终 readOnly。WAL 中的新鲜事件随主库一并可读，无需单独处理。
 *   - 判定卡住后仍需关联进程状态（见 SKILL.md「Windows 进程检查」），
 *     本脚本只解决「存储里是什么状态」。
 */

import { DatabaseSync } from 'node:sqlite'
import { homedir } from 'node:os'
import { join } from 'node:path'

const args = process.argv.slice(2)
const positional = args.filter((a) => !a.startsWith('--') && args[args.indexOf(a) - 1] !== '--db' && args[args.indexOf(a) - 1] !== '--tool' && args[args.indexOf(a) - 1] !== '--last')
const sidPrefix = positional[0]
if (!sidPrefix) {
  console.error('usage: node dump-session-parts.mjs <sessionIdPrefix> [--stuck] [--tool name] [--last N] [--db path]')
  process.exit(1)
}
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`)
  return i >= 0 ? args[i + 1] : def
}
const dbPath = opt('db', join(homedir(), '.local', 'share', 'opencode', 'opencode.db'))
const toolFilter = opt('tool', null)
const lastN = Number(opt('last', 0)) || 0
const stuckOnly = args.includes('--stuck')

const db = new DatabaseSync(dbPath, { readOnly: true })

const sessions = db.prepare(`SELECT id, title FROM session WHERE id LIKE ?`).all(`${sidPrefix}%`)
if (sessions.length !== 1) {
  console.error(`prefix '${sidPrefix}' matched ${sessions.length} sessions:`)
  for (const s of sessions) console.error(`  ${s.id} | ${(s.title || '').slice(0, 60)}`)
  process.exit(1)
}
const sid = sessions[0].id
console.log(`session=${sid} | ${(sessions[0].title || '').slice(0, 70)}`)

let rows = db.prepare(`
  SELECT id, message_id, time_created, time_updated,
         json_extract(data, '$.type') as type,
         json_extract(data, '$.tool') as tool,
         json_extract(data, '$.state.status') as status,
         json_extract(data, '$.state.exit') as exit_code,
         json_extract(data, '$.state.title') as state_title,
         json_extract(data, '$.state.input.command') as command,
         json_extract(data, '$.state.input.description') as description
  FROM part WHERE session_id = ? AND json_extract(data, '$.type') = 'tool' ORDER BY time_created
`).all(sid)

if (toolFilter) rows = rows.filter((r) => r.tool === toolFilter)
if (stuckOnly) rows = rows.filter((r) => r.status && !['completed', 'error'].includes(r.status))
if (lastN > 0) rows = rows.slice(-lastN)

const fmt = (ms) => new Date(ms).toLocaleString('zh-CN', { hour12: false, timeZone: 'Asia/Shanghai' })
for (const r of rows) {
  const desc = (r.description || r.state_title || (r.command || '').slice(0, 60) || '').replace(/\s+/g, ' ').slice(0, 60)
  const ageMin = ((Date.now() - r.time_updated) / 60000).toFixed(0)
  console.log(`${r.id} ${fmt(r.time_created)} tool=${r.tool} status=${r.status ?? '-'} exit=${r.exit_code ?? '-'} idle=${ageMin}min | ${desc}`)
}
console.log(`shown=${rows.length}`)
