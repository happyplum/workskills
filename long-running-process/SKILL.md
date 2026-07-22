---
name: long-running-process
description: 当确认当前运行环境是 Windows + PowerShell，且需要启动或排查长运行进程、等待端口/health endpoint、执行可能超时的构建命令时使用。
---

# 长运行进程安全启动（Windows）

## 概述

OpenCode 的 shell 命令工具在当前环境中运行 PowerShell，并有超时机制（默认 120 秒，环境变量 `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` 可配）。当超时触发时，平台会终止进程树（`taskkill /pid /T /F`）。当前执行链通常无法自动降级重试——不要依赖平台重试恢复。

**核心风险**：

- 在 PowerShell 命令内写无限轮询循环（`while (-not $ready) { Start-Sleep 1 }` 无超时上限），会导致命令永远不返回，最终被平台强制杀死，session 丢失。
- 在 OpenCode Windows shell tool 内用 `Start-Process` 启动长运行进程，可能让子/孙进程继承 stdout/stderr pipe 句柄，导致 Node `close` 事件迟迟不触发。

`WMI Win32_Process.Create` 是长运行后台进程启动的推荐隔离方式，用来降低 pipe 继承风险；它不是所有卡住问题的根治方案，也不适合需要直接捕获 stdout 的普通短命令。

**范围**：本 skill 覆盖 Windows（PowerShell 7+）下的**应用进程**管理——dev server、构建命令、编译任务、任何需要后台运行并等待就绪的进程。浏览器自动化工具（`agent-browser`）有自己的 daemon 架构和独立的问题域，不在本 skill 范围内。Unix/macOS 进程管理也超出范围——使用 `ss`/`lsof`/`pkill` 的原生 shell 模式。

## 框架冷启动预算

内部等待超时必须 ≥ 框架冷启动预算且 < shell tool timeout 减去 15s 余量。

| 框架 | 默认端口 | 热启动 | 冷启动 | 包管理器 |
|------|----------|--------|--------|----------|
| Next.js | 3000 | 15s | 60s | pnpm / npm |
| Vite | 5173 | 5s | 30s | pnpm |
| Flutter Web | 自定 | 20s | 90s | flutter CLI |
| Cargo (axum/actix) | 8080 | 10s | 120s | cargo |
| Storybook | 6006 | 10s | 45s | pnpm / npm |

子代理必须根据实际框架选择预算并证明。不要使用固定 60s。

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **禁止无界等待**：内部轮询/等待循环必须有超时上限，基于框架预算表选择，且 < shell tool timeout | 循环体内有 `$timer -lt $maxWait`，`$maxWait` 引用框架预算 |
| 2 | **长运行后台进程不得用 `Start-Process` 启动**：用 `WMI Win32_Process.Create` 隔离 OpenCode pipe，返回 PID + 日志路径，并做 2s liveness check | `start-background.ps1` 使用 `Win32_Process.Create`；PID 输出前有 liveness check |
| 3 | **就绪检查必须独立、有界、失败 `exit 1`**：用独立 shell tool 调用检查端口/health endpoint，基于框架预算设超时 | `start-background` 与 `wait-ready` 分两个独立 tool call；`wait-ready.ps1` 超时 `exit 1` |
| 4 | **shell tool 必须设置外层 `timeout`**：预期可能长时间运行的命令必须显式设置 `timeout`（毫秒），最大 600,000ms | 工具参数中 `timeout` 字段存在且 ≤ 600000 |
| 5 | **端口占用不得默认成功**：必须验证占用进程的命令行或工作目录属于本任务；无法验证时 `exit 1` 并输出 owning PID/路径 | `start-background`/`cleanup-port` 含 `Get-CimInstance Win32_Process` 命令行校验 |

## 脚本

脚本位于本 skill 目录的 `scripts/` 下，用绝对路径调用（skill 目录见加载时的 location）。每个脚本带 `-Parameter` 参数，无需从 markdown 复制填空。

### 启动 + 就绪（最常用，分两个独立 shell tool 调用）

```powershell
# 1. 启动后台进程（独立 shell tool 调用）
& <skill-dir>/scripts/start-background.ps1 -Pm pnpm.cmd -CommandArgs "dev" -Port 3000 -Dir . -LogPrefix dev
# 2. 就绪检查（独立 shell tool 调用，有界超时）
& <skill-dir>/scripts/wait-ready.ps1 -Port 3000 -MaxWait 60
```

### 脚本清单

| 脚本 | 用途 | 关键参数 |
|---|---|---|
| `start-background.ps1` | WMI 隔离启动长运行后台进程，返回 PID + 日志路径 + 2s liveness check | `-Pm` `-CommandArgs` `-Port` `-Dir` `-LogPrefix` |
| `wait-ready.ps1` | 有界轮询端口/health endpoint 就绪检查，超时 `exit 1` | `-Port` `-MaxWait` `[ -HealthUrl ]` |
| `capture-timed.ps1` | 限时前台捕获（E2E smoke test），运行 N 秒后杀死并输出日志 tail | `-Exe` `-CommandArgs` `-TimeoutSec` `-LogPrefix` |
| `cleanup-port.ps1` | 精确清理占用端口的进程（命令行校验防误杀） | `-Port` `-RequireMatch` |
| `classify-failure.ps1` | 读 stderr 日志分类启动失败原因（端口冲突/缺依赖/语法错误等） | `-LogPath` |

> **start-background 与 wait-ready 必须分两个独立 shell tool 调用**（规则 3）。`cleanup-port` 的 `-RequireMatch` 必须是绝对项目路径或唯一标记——不可用 `node`/`pnpm` 等裸可执行名。

## 反例

```powershell
# ❌ 无界等待
while (-not (Test-NetConnection localhost 3000)) { Start-Sleep 1 }

# ❌ 端口占用默认成功
if ($port) { Write-Output "Port 3000 already in use"; exit 0 }

# ❌ Stop-Process 不杀子进程树
Stop-Process -Id $proc.Id -Force

# ❌ 无 liveness check — PID 可能已死亡
$proc = Start-Process ...; Write-Output "Started PID: $($proc.Id)"

# ❌ Start-Process 启动长运行进程 — pipe 句柄继承导致 Node close 事件不触发
# （所有 -RedirectStandard* 变体、/c 包装变体、裸调用变体均应避免）
# ✅ 用 start-background.ps1（WMI Win32_Process.Create 隔离）
```

## 平台事实

| 参数 | 值 |
|------|-----|
| 范围 | Windows（PowerShell 7+） |
| shell tool 默认超时 | 120,000ms（2 分钟） |
| shell tool 最大超时 | 600,000ms（10 分钟） |
| 超时环境变量 | `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` |
| Windows kill | `taskkill /pid <PID> /T /F`（进程树） |
| 超时后行为 | 命令终止，当前执行链通常无法自动降级重试 |
