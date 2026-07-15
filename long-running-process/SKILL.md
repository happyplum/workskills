---
name: long-running-process
description: 会话开始时必须加载。当在 Windows 上启动长运行进程（dev server、flutter run、npm start 等）、等待端口/health endpoint 就绪、执行可能超时的构建命令，或排查应用进程导致 OpenCode tool call 卡住时使用
---

# 长运行进程安全启动（Windows）

## 概述

OpenCode 的 bash 工具有超时机制（默认 120 秒，环境变量 `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` 可配）。当超时触发时，平台会终止进程树（`taskkill /pid /T /F`）。当前执行链通常无法自动降级重试——不要依赖平台重试恢复。

**核心风险**：

- 在 bash 命令内写无限轮询循环（`while (-not $ready) { sleep 1 }` 无超时上限），会导致命令永远不返回，最终被平台强制杀死，session 丢失。
- 在 OpenCode Windows bash tool 内用 `Start-Process` 启动长运行进程，可能让子/孙进程继承 stdout/stderr pipe 句柄，导致 Node `close` 事件迟迟不触发。

`WMI Win32_Process.Create` 只是长运行后台进程启动的推荐隔离方式，用来降低 pipe 继承风险；它不是所有卡住问题的根治方案，也不适合需要直接捕获 stdout 的普通短命令。

**范围**：本 skill 覆盖 Windows（PowerShell 7+）下的**应用进程**管理——dev server、构建命令、编译任务、任何需要后台运行并等待就绪的进程。浏览器自动化工具（`agent-browser`）有自己的 daemon 架构和独立的问题域，不在本 skill 范围内。Unix/macOS 进程管理也超出范围——使用 `ss`/`lsof`/`pkill` 的原生 shell 模式。

## 加载条件

| 使用 | 不使用 |
|------|--------|
| 启动 dev server、等待端口就绪、运行编译/构建、限时前台捕获 | 普通短命令（<10s）、纯解释、Unix/macOS 环境 |
| `pnpm dev`、`npm start`、`flutter run`、`cargo run`、`next dev`、`vite dev` | 与进程管理无关的文件编辑、搜索、lint |
| 慢但会退出的一次性命令（`pnpm build`、`cargo build`）——仅适用规则 4 | 浏览器自动化（`agent-browser`、Chrome、snapshot）——不在本 skill 范围 |
| | 子代理中断恢复——使用 `interrupted-subagent-recovery` skill |

## 框架冷启动预算

内部等待超时必须 ≥ 框架冷启动预算且 < bash tool timeout 减去 15s 余量。

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
| 1 | **禁止无界等待**：内部轮询/等待循环必须有超时上限，基于框架预算表选择，且 < bash tool timeout | 循环体内有 `$timer -lt $maxWait`，`$maxWait` 引用框架预算 |
| 2 | **长运行后台进程不得用 `Start-Process` 启动**：用 `WMI Win32_Process.Create` 隔离 OpenCode pipe，返回 PID + 日志路径，并做 2s liveness check | 启动模板使用 `Win32_Process.Create`；PID 输出前有 `Get-Process -Id $pid` 存活检查 |
| 3 | **就绪检查必须独立、有界、失败 `exit 1`**：用独立 bash 调用检查端口/health endpoint，基于框架预算设超时 | 两个独立 bash call；检查脚本含 `exit 1` |
| 4 | **bash tool 必须设置外层 `timeout`**：预期可能长时间运行的命令必须显式设置 `timeout`（毫秒），最大 600,000ms | 工具参数中 `timeout` 字段存在且 ≤ 600000 |
| 5 | **端口占用不得默认成功**：必须验证占用进程的命令行或工作目录属于本任务；无法验证时 `exit 1` 并输出 owning PID/路径 | 输出含 `Get-CimInstance Win32_Process` 命令行信息 |

## PowerShell 模板

### 模板 1：启动（立即返回 + liveness check）

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PM = "pnpm.cmd"     # ← 替换: pnpm.cmd / npm.cmd / flutter / cargo
$PORT = 3000          # ← 替换: 查框架预算表
$ARGS = "dev"         # ← 替换: dev / start / run 等
$DIR = "<project>"   # ← 替换: 项目目录
$LOGPREFIX = "dev"    # ← 替换: 日志文件前缀

# 检查端口占用 — 必须验证归属
$port = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($port) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($port.OwningProcess)" |
        Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
    Write-Output "ERROR: Port $PORT already in use.`n$owner"
    exit 1
}

# 启动（用 try/catch 确保缺失二进制时输出可控错误）
try {
    $exe = (Get-Command $PM -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $PM not found; install or fix PATH"
    exit 1
}

$stdoutLog = "$env:TEMP\${LOGPREFIX}-stdout-$PID.log"
$stderrLog = "$env:TEMP\${LOGPREFIX}-stderr-$PID.log"

# 关键：不要用 Start-Process 启动长运行进程（无论是否加 -RedirectStandardOutput）。
# OpenCode bash tool 等待 Node 'close' 事件（cross-spawn-spawner.ts 用 proc.on('close')），
# 而 Start-Process 创建的进程可能继承 PowerShell 的 stdout/stderr pipe 写端，
# 已观察到长运行孙进程持有 pipe 时，'close' 迟迟不触发，tool call 长时间不返回。
# 长运行后台启动优先用 WMI Win32_Process.Create 创建独立进程，降低继承 OpenCode pipe 的风险。
$launcher = "$env:TEMP\${LOGPREFIX}-launch-$PID.cmd"
@"
@echo off
cd /d "$DIR" || exit /b 1
call "$exe" $ARGS 1>"$stdoutLog" 2>"$stderrLog" <NUL
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII

$startup = ([wmiclass]'Win32_ProcessStartup').CreateInstance()
$startup.ShowWindow = 0
$result = ([wmiclass]'Win32_Process').Create("$env:ComSpec /d /c `"$launcher`"", $DIR, $startup)
if ($result.ReturnValue -ne 0) {
    Write-Output "ERROR: Win32_Process.Create failed with code $($result.ReturnValue)"
    exit 1
}

# 2s liveness check — 进程可能立即崩溃
Start-Sleep 2
if (-not (Get-Process -Id $result.ProcessId -ErrorAction SilentlyContinue)) {
    $errLog = Get-Content $stderrLog -Tail 10 -ErrorAction SilentlyContinue
    Write-Output "ERROR: Process $($result.ProcessId) died immediately.`nLast stderr:`n$errLog"
    exit 1
}

Write-Output "Started PID: $($result.ProcessId)"
Write-Output "Logs: $stdoutLog / $stderrLog"
```

### 模板 2：就绪检查（独立 bash 调用，有界超时）

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PORT = 3000              # ← 替换
$MAX_WAIT = 60            # ← 替换: 查框架预算表
$HEALTH_URL = $null       # ← 可选: 如有 health endpoint 则填入

$timer = 0
while ($timer -lt $MAX_WAIT) {
    if ($HEALTH_URL) {
        try {
            $r = Invoke-WebRequest -Uri $HEALTH_URL -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            Write-Output "Health check passed (status $($r.StatusCode))"; exit 0
        } catch { }
    } else {
        $conn = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($conn) { Write-Output "Port $PORT ready (PID $($conn.OwningProcess))"; exit 0 }
    }
    Start-Sleep 2; $timer += 2
}
Write-Output "ERROR: Port $PORT not ready after ${MAX_WAIT}s"
exit 1
```

### 模板 3：限时前台捕获（运行→捕获→杀死）

> 仅用于需要运行 N 秒捕获启动状态然后释放的场景（如 E2E smoke test）。**不要**用于需要持续运行的 QA dev server——改用模板 1 + 模板 2。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TIMEOUT = 90             # ← 替换: 捕获时长
$EXE = "flutter"           # ← 替换
$ARGS = "run","-d","chrome","--web-port=8234"
$LOGPREFIX = "flutter"

$stdoutLog = "$env:TEMP\${LOGPREFIX}-stdout-$PID.log"
$stderrLog = "$env:TEMP\${LOGPREFIX}-stderr-$PID.log"

try {
    $resolved = (Get-Command $EXE -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $EXE not found"; exit 1
}

# 用 WMI 启动降低 pipe 句柄泄漏风险（同模板 1 原因）
$launcher = "$env:TEMP\${LOGPREFIX}-launch-$PID.cmd"
@"
@echo off
"$resolved" $($ARGS -join ' ') 1>"$stdoutLog" 2>"$stderrLog" <NUL
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII

$startup = ([wmiclass]'Win32_ProcessStartup').CreateInstance()
$startup.ShowWindow = 0
$result = ([wmiclass]'Win32_Process').Create("$env:ComSpec /d /c `"$launcher`"", ".", $startup)
if ($result.ReturnValue -ne 0) {
    Write-Output "ERROR: Win32_Process.Create failed with code $($result.ReturnValue)"; exit 1
}
$procId = $result.ProcessId
Write-Output "PID: $procId"

# 有界等待
$elapsed = 0
while ($elapsed -lt $TIMEOUT) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) {
        Write-Output "Process exited naturally"
        break
    }
    Start-Sleep 2; $elapsed += 2
}
if ($elapsed -ge $TIMEOUT) {
    taskkill /pid $procId /T /F 2>$null
    Write-Output "Process tree killed after ${TIMEOUT}s"
}

$stdoutTail = Get-Content -LiteralPath $stdoutLog -Tail 50 -ErrorAction SilentlyContinue
$stderrTail = Get-Content -LiteralPath $stderrLog -Tail 50 -ErrorAction SilentlyContinue
Write-Output "Last stdout:`n$(($stdoutTail) -join "`n")"
Write-Output "Last stderr:`n$(($stderrTail) -join "`n")"
```

### 模板 4：清理残留进程

```powershell
$PORT = 3000
$REQUIRE_MATCH = "<required-commandline-substring>"  # Use an absolute project path, unique tool session/port marker, or full command fragment. Do not use bare executable names like node, pnpm, or chrome.

if ($REQUIRE_MATCH -eq "<required-commandline-substring>") {
    Write-Output "ERROR: Set REQUIRE_MATCH before cleanup. Refusing to kill an unscoped PID."
    exit 1
}

$conn = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($conn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    if (-not $owner) {
        Write-Output "ERROR: Owning process $($conn.OwningProcess) not found. Refusing cleanup."
        exit 1
    }

    $ownerInfo = $owner | Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
    Write-Output "Candidate owner:`n$ownerInfo"

    $commandLine = $owner.CommandLine
    if (($null -eq $commandLine) -or ($commandLine.IndexOf($REQUIRE_MATCH, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
        Write-Output "ERROR: PID $($conn.OwningProcess) does not match REQUIRE_MATCH '$REQUIRE_MATCH'. Refusing cleanup."
        exit 1
    }

    taskkill /pid $conn.OwningProcess /T /F 2>$null
    Write-Output "Killed process tree for PID $($conn.OwningProcess)"
} else {
    Write-Output "Port $PORT is free"
}
```

### 模板 5：启动失败分类（诊断用）

> 当模板 1 启动成功但模板 2 超时时，用此模板读取日志分类失败原因。

```powershell
Set-StrictMode -Version Latest
$LOG = "$env:TEMP\dev-stderr-<PID>.log"  # ← 替换为模板 1 输出的 stderr 日志

if (-not (Test-Path $LOG)) { Write-Output "ERROR: Log file not found: $LOG"; exit 1 }

$tail = Get-Content $LOG -Tail 50 -ErrorAction SilentlyContinue
$errors = @(
    @{ Pattern = "EADDRINUSE|address already in use"; Reason = "Port conflict — another process using this port" },
    @{ Pattern = "ENOENT|Cannot find module|Error: Cannot resolve"; Reason = "Missing dependency — run pnpm install" },
    @{ Pattern = "SyntaxError|Unexpected token|Expected"; Reason = "Syntax error in source code" },
    @{ Pattern = "ENOMEM|heap out of memory|FATAL ERROR"; Reason = "Out of memory — close other processes or increase Node heap" },
    @{ Pattern = "EACCES|permission denied"; Reason = "Permission error — check file/directory permissions" }
)

foreach ($e in $errors) {
    if ($tail | Select-String -Pattern $e.Pattern -Quiet) {
        Write-Output "ERROR: $($e.Reason)`nLast 10 lines:`n$(($tail | Select-Object -Last 10) -join "`n")"
        exit 1
    }
}

Write-Output "WARNING: No known error pattern matched. Raw last 20 lines:`n$(($tail | Select-Object -Last 20) -join "`n")"
exit 1
```

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

# ❌ 缺失二进制时 PS 原生异常而非可控错误
$exe = (Get-Command nonexistent.cmd -ErrorAction Stop).Source

# ❌ Start-Process 启动长运行进程 — 在 OpenCode Windows bash tool 下属于高风险 pipe 继承模式
# OpenCode bash tool 等待 Node 'close' 事件（proc.on('close')），
# Start-Process 创建的进程可能继承 PowerShell 的 stdout/stderr pipe 写端，
# 已观察到长运行孙进程持有 pipe 时，'close' 迟迟不触发，tool call 长时间不返回。
# 以下变体都应避免用于长运行后台启动：
$proc = Start-Process -FilePath "pnpm" -RedirectStandardOutput $log -RedirectStandardError $err ...
$proc = Start-Process -FilePath "$env:ComSpec" -ArgumentList "/c pnpm dev" ...
$proc = Start-Process -FilePath "pnpm" -ArgumentList "dev" ...  # 即使不加 -RedirectStandard*
# ✅ 长运行后台启动的推荐隔离方案：WMI Win32_Process.Create（见模板 1）
```

## 最小 CSO 触发词

- 主要：`pnpm dev`、`npm start`、`flutter run`、`cargo run`、`next dev`、`vite dev`、`dev server`、`Start-Process`、`port 3000`、`Get-NetTCPConnection`、`taskkill`、`waiting for port`
- 次要：`hang`、`卡住`、`超时`、`running`、`close event`、`detached`、`background process`、`long-running`、`cargo build`、`pnpm build`、`timeout`

## 平台事实

| 参数 | 值 |
|------|-----|
| 范围 | Windows（PowerShell 7+） |
| bash 工具默认超时 | 120,000ms（2 分钟） |
| bash 工具最大超时 | 600,000ms（10 分钟） |
| 超时环境变量 | `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` |
| Windows kill | `taskkill /pid <PID> /T /F`（进程树） |
| 超时后行为 | 命令终止，当前执行链通常无法自动降级重试 |
