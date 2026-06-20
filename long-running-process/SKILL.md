---
name: long-running-process
description: 会话开始时必须加载。当在 Windows 上启动长运行进程（dev server、flutter run、npm start 等）、等待端口/health endpoint 就绪、或执行可能超时的编译构建命令时使用
---

# 长运行进程安全启动（Windows）

## 概述

OpenCode 的 bash 工具有超时机制（默认 120 秒，环境变量 `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` 可配）。当超时触发时，平台会终止进程树（`taskkill /pid /T /F`）。当前执行链通常无法自动降级重试——不要依赖平台重试恢复。

**核心风险**：在 bash 命令内写无限轮询循环（`while (-not $ready) { sleep 1 }` 无超时上限），会导致命令永远不返回，最终被平台强制杀死，session 丢失。

**范围**：本 skill 仅覆盖 Windows（PowerShell 7+）。Unix/macOS 进程管理超出范围——使用 `ss`/`lsof`/`pkill` 的原生 shell 模式。

## 加载条件

| 使用 | 不使用 |
|------|--------|
| 启动 dev server、等待端口就绪、运行编译/构建、限时前台捕获 | 普通短命令（<10s）、纯解释、Unix/macOS 环境 |
| `pnpm dev`、`npm start`、`flutter run`、`cargo run`、`next dev`、`vite dev` | 与进程管理无关的文件编辑、搜索、lint |
| 慢但会退出的一次性命令（`pnpm build`、`cargo build`）——仅适用规则 4 | 子代理中断恢复——使用 `interrupted-subagent-recovery` skill |

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
| 2 | **长运行进程必须后台启动并返回 PID + 2s liveness check**：`Start-Process -PassThru` 启动后 sleep 2s 验证进程存活，输出 PID 和日志路径，立即 exit | PID 输出前有 `Get-Process -Id $pid` 存活检查 |
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

# 关键：不要用 Start-Process -RedirectStandardOutput/-RedirectStandardError
# 那会让 OpenCode 的 stdout/stderr pipe 句柄泄漏给长运行孙进程（node.exe），
# 导致 bash tool 永远等不到 pipe EOF，tool call 永不返回。
# 改用 cmd.exe /c 内部重定向，让日志重定向发生在子进程 shell 内。
$cmd = "/d /s /c `"$exe $ARGS 1> `"$stdoutLog`" 2> `"$stderrLog`"`""
$proc = Start-Process -FilePath "$env:ComSpec" `
    -ArgumentList $cmd `
    -WorkingDirectory $DIR `
    -PassThru -WindowStyle Hidden

# 2s liveness check — 进程可能立即崩溃
Start-Sleep 2
if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
    $errLog = Get-Content $stderrLog -Tail 10 -ErrorAction SilentlyContinue
    Write-Output "ERROR: Process $($proc.Id) died immediately.`nLast stderr:`n$errLog"
    exit 1
}

Write-Output "Started PID: $($proc.Id)"
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

# 用 cmd.exe /c 内部重定向，避免 pipe 句柄泄漏给长运行进程
$cmd = "/d /s /c `"$resolved $($ARGS -join ' ') 1> `"$stdoutLog`" 2> `"$stderrLog`"`""
$proc = Start-Process -FilePath "$env:ComSpec" `
    -ArgumentList $cmd `
    -PassThru -WindowStyle Hidden
Write-Output "PID: $($proc.Id)"
$proc.WaitForExit($TIMEOUT * 1000)
if (-not $proc.HasExited) {
    taskkill /pid $proc.Id /T /F 2>$null
    Write-Output "Process tree killed after ${TIMEOUT}s"
} else {
    Write-Output "Process exited with code $($proc.ExitCode)"
}
```

### 模板 4：清理残留进程

```powershell
$PORT = 3000  # ← 替换
$conn = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($conn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    # 确认工作目录属于本任务后再清理
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

# ❌ Start-Process -RedirectStandardOutput/Error 导致 pipe 句柄泄漏给孙进程
# bash tool 永远等不到 pipe EOF，tool call 永不返回
$proc = Start-Process -FilePath "pnpm" -RedirectStandardOutput $log -RedirectStandardError $err ...
# ✅ 改用 cmd.exe /c 内部重定向（见模板 1）

# ❌ 硬编码框架/端口
$proc = Start-Process -FilePath "pnpm" -ArgumentList "dev" ... -LocalPort 3000
```

## 最小 CSO 触发词

- 主要：`pnpm dev`、`npm start`、`flutter run`、`cargo run`、`next dev`、`vite dev`、`dev server`、`Start-Process`、`port 3000`、`Get-NetTCPConnection`、`taskkill`、`waiting for port`
- 次要：`hang`、`卡住`、`超时`、`detached`、`background process`、`long-running`、`cargo build`、`pnpm build`、`timeout`

## 平台事实

| 参数 | 值 |
|------|-----|
| 范围 | Windows（PowerShell 7+） |
| bash 工具默认超时 | 120,000ms（2 分钟） |
| bash 工具最大超时 | 600,000ms（10 分钟） |
| 超时环境变量 | `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` |
| Windows kill | `taskkill /pid <PID> /T /F`（进程树） |
| 超时后行为 | 命令终止，当前执行链通常无法自动降级重试 |

## PowerShell 模板

### 模板 1：启动（立即返回）

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 检查端口占用 — 必须验证归属
$port = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($port) {
    $owner = Get-Process -Id $port.OwningProcess -ErrorAction SilentlyContinue |
        Select-Object Id, Path, @{N='CmdLine';E={(Get-CimInstance Win32_Process -Filter "ProcessId=$($port.OwningProcess)").CommandLine}} |
        Format-List | Out-String
    Write-Output "ERROR: Port 3000 already in use.`n$owner"
    exit 1
}

# 启动（用 .cmd shim 确保路径解析）
$exe = (Get-Command pnpm.cmd -ErrorAction Stop).Source
$proc = Start-Process -FilePath $exe -ArgumentList "dev" -WorkingDirectory "<project-dir>" `
    -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput "$env:TEMP\dev-stdout.log" `
    -RedirectStandardError "$env:TEMP\dev-stderr.log"
Write-Output "Started PID: $($proc.Id)"
```

### 模板 2：就绪检查（独立 bash 调用，有界超时）

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$maxWait = 60; $timer = 0
while ($timer -lt $maxWait) {
    $conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($conn) { Write-Output "Port 3000 ready (PID $($conn.OwningProcess))"; exit 0 }
    Start-Sleep 2; $timer += 2
}
Write-Output "ERROR: Port 3000 not ready after ${maxWait}s"
exit 1
```

### 模板 3：带超时的前台进程（flutter run 等）

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$timeout = 90
$proc = Start-Process -FilePath "flutter" -ArgumentList "run","-d","chrome","--web-port=8234" `
    -PassThru -NoNewWindow `
    -RedirectStandardOutput "$env:TEMP\flutter-stdout.log" `
    -RedirectStandardError "$env:TEMP\flutter-stderr.log"
Write-Output "PID: $($proc.Id)"
$proc.WaitForExit($timeout * 1000)
if (-not $proc.HasExited) {
    taskkill /pid $proc.Id /T /F 2>$null
    Write-Output "Process tree killed after ${timeout}s"
} else {
    Write-Output "Process exited with code $($proc.ExitCode)"
}
```

### 模板 4：清理残留进程

```powershell
# 仅对已确认归属的 PID 使用 — 先通过端口、命令行、工作目录至少两项确认
$port = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($port) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($port.OwningProcess)"
    # 确认进程工作目录属于本任务后再清理
    taskkill /pid $port.OwningProcess /T /F 2>$null
    Write-Output "Killed process tree for PID $($port.OwningProcess)"
}
```
