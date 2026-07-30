---
name: long-running-process
description: 当确认当前运行环境是 Windows + PowerShell，且需要启动或排查长运行进程、等待端口/health endpoint、按 RunId 停止残留、或执行可能超时的构建命令时使用。
---

# 长运行进程安全启动（Windows）

## 概述

OpenCode shell 在 Windows 上跑 PowerShell，并有**可配置**超时；超时会 `taskkill /T /F` 杀命令树。当前执行链通常不能自动降级重试。

**核心风险**：

- 无界轮询（`while` 无上限）→ 命令永不返回 → 被平台杀死
- 在 **OpenCode shell 内**用 `Start-Process` 启长运行进程 → 子进程可能继承 pipe → Node `close` 不触发
- **WMI 启动的应用是 detached 的**：`wait-ready` 失败或 shell 超时后，app **仍可能存活**。无 RunId ownership 时会变成 unmanaged orphan

**推荐模型**：`WMI` → ASCII-only `cmd` launcher（仅含 pwsh/supervisor/config 的 ASCII 路径）→ **PowerShell supervisor** → `ProcessStartInfo.ArgumentList` 启应用（AppPid）。用户参数与 Unicode 工作目录只在 UTF-8 JSON config 中。ControlPid 为 cmd 树根。State：`%TEMP%\opencode-long-running\<RunId>.json`。

**范围**：Windows（PowerShell 7+）**应用进程**（dev server、构建、watcher）。`agent-browser` 不在范围。Unix/macOS 不在范围。

**与恢复 skill**：中断后续派前须证明旧 writer 已停且残留可复用/已停；应用侧 stop/cleanup 由本 skill 脚本完成，派发决策见 `interrupted-subagent-recovery`。

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **禁止无界等待**：内部等待必须有 `MaxWait`；且 `MaxWait + cleanup margin < 本次显式 outer timeout` | 循环有上限；outer `timeout` 显式且更大 |
| 2 | **长运行后台不得在 OpenCode shell 内 `Start-Process`**：用 `start-background.ps1`（WMI → ASCII launcher → supervisor + ArgumentList） | `.cmd` 仅含 ASCII 路径、无用户参数；输出含 RunId/ControlPid/AppPid/State |
| 3 | **就绪检查独立、有界、失败 exit 1**：与 start 分两个 tool call；有 RunId 时 listener 必须属于该 control 树 | `wait-ready -RunId`；外来占端口 → 失败 |
| 4 | **可能长跑的 shell 必须显式 `timeout`（ms）**：不依赖平台默认值写预算；默认/最大值以**当前** tool schema 为准，skill 不固化易漂移数字 | 调用带 `timeout=`；与 MaxWait 一致可算 |
| 5 | **端口占用不得默认成功**：start 前占用 → fail；ready 必须 ownership；cleanup 多 listener → 拒绝 | 见脚本 exit 1 文案 |
| 6 | **停止走 RunId**：非端口 watcher 也必须能 `stop-background -RunId`；禁止只记 PID 文本当契约 | state 文件存在且 stop 后树消失 |

## 超时预算（无版本断言）

- **唯一稳定式**：`inner MaxWait + cleanup margin < 本次调用显式 outer timeout`
- 冷启动选足够大的 `MaxWait`（按项目经验），**不要**抄已过时的「默认 120s」表当真理
- 参考量级（非硬编码 SLA）：Vite 热 ~数秒～30s；Next 冷可到 ~60s；Cargo 冷可到数分钟——**以本次 outer timeout 能盖住为准**

## 脚本

路径：`<skill-dir>/scripts/`（skill location 见加载信息）。

### 启动 + 就绪 + 停止

```powershell
# 1. 启动（独立 shell tool call；CommandArgs 用数组）
& <skill-dir>/scripts/start-background.ps1 -Pm pnpm.cmd -CommandArgs @('dev') -Port 3000 -Dir 'C:\proj' -LogPrefix dev
# 2. 就绪（独立 call；用返回的 RunId）
& <skill-dir>/scripts/wait-ready.ps1 -RunId <RunId> -MaxWait 60
# 可选 health：
# & <skill-dir>/scripts/wait-ready.ps1 -RunId <RunId> -MaxWait 60 -HealthUrl http://localhost:3000/
# 3. 停止
& <skill-dir>/scripts/stop-background.ps1 -RunId <RunId>
```

无端口的 watcher/构建长任务：省略 `-Port`，仅用 RunId 生命周期。

| 脚本 | 用途 | 关键参数 |
|---|---|---|
| `start-background.ps1` | WMI supervisor 启动；写 RunId state | `-Pm` `-CommandArgs` `[-Port]` `-Dir` `-LogPrefix` |
| `wait-ready.ps1` | 有界 ready；`-RunId` 时校验 listener 归属 | `-MaxWait` `[-RunId]` `[-Port]` `[-HealthUrl]` |
| `stop-background.ps1` | 按 RunId taskkill 树并验证 | `-RunId` `[-RequirePortFree]` |
| `capture-timed.ps1` | 限时捕获后杀树（smoke） | `-Exe` `-CommandArgs` `-TimeoutSec` `-LogPrefix` `[-Dir]` |
| `cleanup-port.ps1` | 无 RunId 时按端口+RequireMatch 清理；多 listener 拒绝 | `-Port` `-RequireMatch` |
| `classify-failure.ps1` | 读 stderr 粗分类 | `-LogPath` |
| `common.ps1` / `supervisor-run.ps1` | 内部原语；不要直接当业务入口 | — |

> `cleanup-port` 的 `-RequireMatch` 必须是绝对项目路径或唯一标记，禁止 `node`/`pnpm` 裸名。优先 `stop-background -RunId`。

State 目录：`%TEMP%\opencode-long-running\<RunId>.json`（含 ControlPid、AppPid、WorkDir、Port、日志路径）。

## 反例

| ❌ | ✅ |
|---|---|
| 无界 `while { Start-Sleep 1 }` | `wait-ready -MaxWait N` |
| 端口已监听就 `exit 0` | 无 RunId 归属证明则失败 |
| OpenCode shell 内 `Start-Process` 挂 dev server | `start-background.ps1` |
| ASCII `.cmd` + 拼接 `CommandArgs` | ArgumentList + UTF-8 config |
| 只保存 "PID: 1234" 跨 session 再杀 | 使用 RunId state + `stop-background` |
| ready 超时后不经 stop 再 start | 先 stop/cleanup 或证明旧进程可复用 |
| 依赖 skill 写死的「默认 120s」算预算 | 每次显式 outer timeout + MaxWait |

## 平台事实（易变 — 以运行时为准）

| 项 | 说明 |
|---|---|
| 范围 | Windows，PowerShell 7+ |
| shell 默认/最大 timeout | **读当前 bash/shell tool schema**；本 skill 不写死毫秒数 |
| 超时 kill | `taskkill /pid … /T /F` |
| detached 语义 | WMI 子树不因 wait-ready 的 exit 1 而自动消失 |
| 编码 | 路径与参数经 JSON/ArgumentList，支持 Unicode 工作目录 |
