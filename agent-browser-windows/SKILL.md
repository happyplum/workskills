---
name: agent-browser-windows
description: 会话开始时必须加载。当在 Windows 上使用 agent-browser（浏览器自动化、打开网页、填表、点击、截图、抓取数据、QA smoke test、E2E 验证）或排查 agent-browser/Chrome 残留导致 OpenCode tool call 卡 running 时使用。提供防卡死调用规则、强制收尾机制、基于 sidecar 文件的精确孤儿进程清理。
allowed-tools: Bash(agent-browser:*), Bash(powershell:*), Bash(taskkill:*), Bash(where:*), Bash(ls:*), Bash(mkdir:*)
---

# agent-browser 安全使用（Windows）

## 概述

本 skill 处理 `agent-browser` 在 Windows OpenCode 环境下的进程安全：**串行化调用、强制收尾、孤儿进程清理**。`agent-browser` 是 Rust CLI，通过 CDP 驱动 Chrome/Chromium，采用 daemon + Chrome 子树的进程模型。这个模型有三个固有特性需要专门应对：多 subagent 并发冲突、daemon 脱离进程树、sidecar 状态文件生命周期。

**先理解为什么会卡，再看规则。** agent-browser 的进程模型：

```
agent-browser <cmd>           ← 你执行的 CLI，是个短命令：连上 daemon、发指令、退出
        │ (首次 open 时 spawn)
        ▼
agent-browser-win32-x64.exe   ← daemon（长驻），持有 Chrome
        │ (spawn)
        ▼
chrome.exe --remote-debugging-port=0
  --user-data-dir=%TEMP%\agent-browser-chrome-<GUID>   ← 整棵 Chrome 子树
```

**执行模型限制（理解所有防线的前提）**：OpenCode 同一 session 内的 bash 调用是**串行的**。一旦某个 agent-browser 命令卡住（如 `open` 连不上目标，实测 Chrome 导航超时可达 138s+），bash tool 阻塞等待它返回，后续所有 bash 调用全部排队，subagent **自己也被锁死在执行链里**，无法调用清理脚本自救。agent-browser 自身的 action timeout（25s）和 IPC timeout（30s）对 `open` 等待页面加载的场景**不生效**——它等的是 Chrome 导航超时（远超 OpenCode 默认 120s）。唯一能让卡住的命令返回的是 bash tool 的外层 timeout。

**因此：防卡住（让命令在可控时间内一定返回）是第一优先级，比卡住后清理更重要。** 本 skill 的模板 B/C/D（清理/诊断）只能在**非卡住状态**下使用——工作流开始前的预防性清理、或超时恢复后的事后清理，**救不了正在发生的卡住**。

卡住/残留的根因（已在 0.29.1–0.31.2 上实验验证）：

1. **并发是主放大器**：多个 OpenCode subagent 同时调用 `agent-browser` 会互相劫持 session、争抢 profile/Chrome 资源，甚至静默崩溃（官方 issue [#326](https://github.com/vercel-labs/agent-browser/issues/326) session 劫持、[#1378](https://github.com/vercel-labs/agent-browser/issues/1378) session 冲突致 Chrome 静默崩溃、[#86](https://github.com/vercel-labs/agent-browser/issues/86) 共享实例互相干扰）。社区共识：**用 lock-based 串行化**，而非依赖 idle timeout（[#885](https://github.com/vercel-labs/agent-browser/issues/885)）。官方的 process-group 修复仅覆盖 daemon 正常退出路径——OpenCode bash tool 超时强杀时绕过它（[#1397](https://github.com/vercel-labs/agent-browser/issues/1397)）。
2. **daemon 脱离 bash 进程树**：daemon 由首次 `open` spawn，之后跨命令复用。当 OpenCode bash tool 超时执行 `taskkill /T /F` 时，daemon 及其 Chrome 子树**不在该命令的进程树内**，杀不掉。实测 daemon 的父进程 PID 已死（`parentAlive=False`）是常态。
3. **`close` 在 sidecar 断裂后失效**：`close` / `close --all` 依赖 sidecar `.pid` 文件定位 daemon。父 shell 被强杀后 session↔daemon 关联可能断裂，`close --all` 实测后仍残留 Chrome。**0.31 的 idle timeout 缓解了"忘了 close"的场景**（见下），但 sidecar 断裂时仍需模板 B 兜底。
4. **`AGENT_BROWSER_IDLE_TIMEOUT_MS`（0.31 已生效，作为安全网）**：0.29.1 时因 select loop bug（[#1110](https://github.com/vercel-labs/agent-browser/issues/1110)）不生效；0.31.2 实测已修复——设为 4000ms 后 daemon 在 ~4s 空闲后自动关闭并清理 Chrome 子树。**但它是计时器兜底，不替代主动 `close`**：锁的释放依赖工作完成即 close（立即让出给排队者），不能等 timeout。
5. **`.engine` 文件永久残留**：每个用过的 session 名都会留下一个 6 字节的 `<session>.engine`（内容恒为 `chrome`），从不自动清理——残留堆积的来源，需定期清理。
6. **`doctor --fix` 有效但过重**：含网络检查 + launch test，不适合常规收尾。

**一句话结论**：**防卡住超时 wrapper（优先级最高）→ 全局串行化锁 → 主动 `close` → sidecar 验证零残留 → 必要时精确 `taskkill`**。模板 B/C/D 是事前预防/事后清理工具，不是卡住自救工具。idle timeout 是额外安全网，不替代主动 close。

**范围**：本 skill 仅覆盖 Windows（PowerShell 7+ / Git Bash）。agent-browser 的命令用法（snapshot、ref、click、fill 等）见 CLI 自带的 `agent-browser skills get core`——本 skill 不重复，只管 Windows 下的进程安全。

## 加载条件

| 使用 | 不使用 |
|------|--------|
| 任何 `agent-browser` 命令（open、snapshot、click、screenshot、wait、QA） | 应用进程管理（dev server 启动、端口等待、构建） |
| tool call 卡在 `running`、怀疑浏览器残留 | 与浏览器无关的文件编辑、搜索、lint |
| 发现 `agent-browser-win32-x64.exe`、chrome 孤儿、`.agent-browser\*.engine` 堆积 | Unix/macOS 浏览器自动化 |
| 浏览器 smoke test、E2E 验证、抓取页面 | |

## sidecar 文件机制（清理的数据源）

每个活跃 session 在 `~/.agent-browser/`（即 `C:\Users\Administrator\.agent-browser\`）下有 **5 件套**：

| 文件 | 内容 | 用途 |
|------|------|------|
| `<session>.engine` | 恒为 `chrome` | 引擎类型标记。**用过的 session 永久留下，不自动清理** |
| `<session>.pid` | daemon 的 PID | **精确清理的可靠依据** |
| `<session>.port` | CDP 调试端口 | |
| `<session>.stream` | streaming 端口 | |
| `<session>.version` | 如 `0.31.2` | 版本一致性检查 |

判定 session 状态：

- **活跃**：5 件套齐全，且 `.pid` 里的 PID 在进程表中存活且 `ProcessName = agent-browser-win32-x64`。
- **僵尸/孤儿**：有 `.pid` 但该 PID 已死（daemon 被强杀，Chrome 子树可能还活着）。
- **历史残留**：只有 `.engine`，无 `.pid`/`.port`/`.stream`/`.version`（之前正常 close 过，只剩引擎标记）。

清理脚本的精确性完全来自 `.pid` 文件：读它 → 验证 PID 存活且进程名匹配 → `taskkill /T /F`。不靠模糊的进程名扫描。

## 安全边界（清理前必读）

agent-browser 的 Chrome 与用户真实 Chrome **完全可区分**，但清理脚本必须同时校验**两个标记**才能杀：

| 标记 | agent-browser Chrome | 用户真实 Chrome |
|------|---------------------|----------------|
| 可执行路径 | `...\.agent-browser\browsers\chrome-<ver>\chrome.exe` | `...\Google\Chrome\Application\chrome.exe` |
| user-data-dir | `--user-data-dir=...\Temp\agent-browser-chrome-<GUID>` | `...\Google\Chrome\User Data` |

**绝不**按进程名 `chrome.exe` 直接杀——会误杀用户浏览器。必须校验命令行同时含可执行路径标记 **和** `agent-browser-chrome-` user-data-dir 标记。`agent-browser-win32-x64.exe` 进程名唯一，可直接按名处理。

> **PowerShell 正则陷阱**：匹配路径中的反斜杠时，**不要用** `\.agent-browser[\\/]browsers`——实测在 PowerShell `-match` 中 `[\\/]` 字符类对 `\` 匹配失败（返回 False），会让路径校验静默失效。用通配 `.` 代替分隔符：`agent-browser.+browsers`（`.` 匹配 `\` 或 `/`，跨平台且可靠）。本 skill 的模板均已用此写法。

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **防卡住超时 wrapper（最高优先级）**：每个 agent-browser 命令必须包在可靠的超时里执行。`open`/`wait` 连不上目标或等页面加载时，agent-browser 自身 timeout 不生效，实测可卡 138s+，导致 subagent 执行链阻塞无法自救。必须用 PowerShell `Start-Process` + `WaitForExit(timeout)` + 超时 `taskkill /T /F` 包裹（**不可用** Git Bash `timeout` 命令——它发 SIGTERM 杀不掉 Windows 原生进程）。见模板 F | 命令经 `Invoke-AB` wrapper 执行；wrapper 含 `WaitForExit` + 超时 kill |
| 2 | **全局串行化锁**：任何 agent-browser 命令前必须先获取全局锁，确保同一时间只有一个 session 在工作。多个 subagent/命令必须排队等待。这是根治并发的关键（官方 #326/#1378/#885 确认并发是冲突主因） | 工作流以 `Acquire-Lock` 开始、`Release-Lock` 结束；见模板 E |
| 3 | **必须用命名 session**：每条 agent-browser 命令带 `--session <task-name>`，不复用 `default` 或不明来源 session。session 名要任务相关且唯一（如 `wallet-qa`、`settings-smoke`） | 命令含 `--session <name>`，且 name 非 `default` |
| 4 | **完成后必须显式 close**：工作流末尾执行 `agent-browser --session <name> close` 立即释放锁。idle timeout（见规则 10）是兜底安全网，不替代主动 close——锁的即时让出只靠 close | 命令链末尾有 `close` |
| 5 | **close 后必须验证零残留**：独立调用检查该 session 的 `.pid` sidecar 已消失、对应 daemon PID 已死 | 验证脚本输出 `closed cleanly`，或列出残留 |
| 6 | **等待优先具体条件**：优先 `wait @ref` / `wait --text "..."` / `wait --url "**/path"`；`networkidle` 仅作兜底，不设为默认；禁止裸 `wait <ms>` | wait 命令非裸 `wait <ms>` |
| 7 | **孤儿清理必须双重校验**：清理 Chrome 必须同时校验可执行路径标记 **和** `agent-browser-chrome-` user-data-dir；绝不按进程名单杀；daemon 用 `.pid` + 进程名双校验 | 清理脚本含两处路径校验 |
| 8 | **清理前后必须计数对比**：清理脚本输出清理前后的 daemon/chrome 进程数，证明有效 | 输出含 before/after 计数 |
| 9 | **模板 B/C/D 的使用时机**：这些是**事前预防/事后清理**工具，不是卡住自救工具（卡住时执行链阻塞，无法调用它们）。在工作流开始前（预防性清理残留）或超时/崩溃恢复后（事后清理）使用 | 非在卡住的 bash 调用内使用 |
| 10 | **配置 idle timeout 安全网（0.31+）**：设 `AGENT_BROWSER_IDLE_TIMEOUT_MS`（如 60000），daemon 空闲超时后自动关闭并清理 Chrome。这是"忘了 close / 崩溃残留"的兜底，不是主收尾 | 环境变量在 open 前 export |

## PowerShell 模板

### 串行化锁（所有工作流的前提）

**为什么需要全局锁**：OpenCode 的多个 subagent 是独立进程，可能同时调用 `agent-browser`。并发会导致：session 互相劫持（#326）、Chrome 静默崩溃（#1378）、共享实例干扰（#86）。官方无内置串行机制，社区共识是 lock-based（#885）。本 skill 用**文件锁**实现全局串行化。

**锁语义**（关键设计，匹配 OpenCode 进程模型）：

- **锁绑定 session 名**，不绑定 bash 进程 PID——因为每个 `Bash` 工具调用是独立进程，PID 每次不同；但 daemon 在工作期间持续存活，session 名跨命令稳定。
- **获取**：`FileMode.CreateNew` 原子创建锁文件（无 TOCTOU 竞态）。若文件已存在，读持有者 session 名，检查其 daemon 是否存活（`.pid` sidecar + 进程名）。
  - 持有者 daemon **存活** → 有界轮询等待（最多 `MAX_WAIT` 秒）。
  - 持有者 daemon **已死/无 sidecar**（上一个工作流正常 close 了，或崩溃了）→ 抢占陈旧锁，删除后重试。
- **释放**：`close` + 验证零残留后，**仅当锁文件仍指向自己的 session 名**才删除（防止误删别人的锁）。
- **锁文件**：`%TEMP%\agent-browser-global.lock`，内容 `SESSION=<name>` + `ACQUIRED=<ISO 时间戳>`。

**与 idle timeout 的交互（0.31+）**：设了 `AGENT_BROWSER_IDLE_TIMEOUT_MS` 后，若持有者 daemon 因空闲超时自动关闭，其 `.pid` sidecar 会被先清理——`Test-SessionDaemonAlive` 随即返回 false，锁被正确识别为陈旧并可抢占。这是安全的（持有者已不在工作）。**但 idle timeout 必须设得足够长（推荐 60000ms）**：太短（如 <15s）会在正常 bash 命令间隙触发，导致 daemon 被过早关闭、后续命令 spawn 新 daemon，打断工作流。

> **PowerShell 正则陷阱**：匹配路径反斜杠时不要用 `[\\/]` 字符类（实测对 `\` 失败）。本 skill 模板用通配 `.`（如 `agent-browser.+browsers`）或 `-replace` 提取，已规避此陷阱。

### 模板 E：串行化锁原语（acquire + release）

> 工作流的**首尾必须调用**这两个函数。建议把模板 E 的函数定义放在脚本开头，模板 A/B/C 的逻辑夹在 `Acquire-Lock` 和 `Release-Lock` 之间。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ===== 锁原语定义 =====
$LOCK_PATH = "$env:TEMP\agent-browser-global.lock"
$HOME_DIR  = "$env:USERPROFILE\.agent-browser"

function Test-SessionDaemonAlive {
    # 通过 .pid sidecar 判断某 session 的 daemon 是否存活
    param([string]$SessionName)
    $pidFile = Join-Path $HOME_DIR "$SessionName.pid"
    if (-not (Test-Path $pidFile)) { return $false }
    $dpid = (Get-Content $pidFile -Raw).Trim()
    $proc = Get-Process -Id $dpid -ErrorAction SilentlyContinue
    return ($null -ne $proc -and $proc.ProcessName -eq 'agent-browser-win32-x64')
}

function Get-LockHolder {
    # 读锁文件里的 session 名（用 -replace 提取，避免正则陷阱）
    if (-not (Test-Path $LOCK_PATH)) { return $null }
    $line = (Get-Content $LOCK_PATH -ErrorAction SilentlyContinue) |
        Where-Object { $_ -like 'SESSION=*' } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace '^SESSION=', '').Trim()
}

function Acquire-Lock {
    param(
        [Parameter(Mandatory)][string]$Session,
        [int]$MaxWaitSec = 120
    )
    $timer = 0
    while ($timer -lt $MaxWaitSec) {
        # 原子获取：CreateNew 仅在文件不存在时成功，天然无竞态
        try {
            $fs = [System.IO.File]::Open($LOCK_PATH,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None)
            $content = "SESSION=$Session`nACQUIRED=$(Get-Date -Format 'o')"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Flush(); $fs.Close()
            Write-Output "[lock] acquired by session '$Session'"
            return $true
        } catch [System.IO.IOException] {
            # 锁已存在 — 检查持有者是否还活着
            $holder = Get-LockHolder
            if ($holder -and (Test-SessionDaemonAlive $holder)) {
                # 持有者仍活跃 — 等待
                if ($timer % 10 -eq 0) {
                    Write-Output "[lock] waiting: held by active session '$holder' (${timer}s/$MaxWaitSec)"
                }
            } else {
                # 持有者 daemon 已死或无 sidecar — 抢占陈旧锁
                Write-Output "[lock] stealing stale lock (was held by '$holder', daemon not alive)"
                Remove-Item $LOCK_PATH -Force -ErrorAction SilentlyContinue
                continue  # 立即重试 CreateNew
            }
        }
        Start-Sleep -Milliseconds 1000
        $timer += 1
    }
    Write-Output "ERROR: [lock] could not acquire within ${MaxWaitSec}s (held by '$(Get-LockHolder)')"
    return $false
}

function Release-Lock {
    param([Parameter(Mandatory)][string]$Session)
    if (-not (Test-Path $LOCK_PATH)) {
        Write-Output "[lock] no lock file to release"
        return
    }
    $holder = Get-LockHolder
    if ($holder -eq $Session) {
        Remove-Item $LOCK_PATH -Force
        Write-Output "[lock] released by session '$Session'"
    } else {
        # 不删别人的锁 — 只报告
        Write-Output "[lock] SKIP release: owned by '$holder', not '$Session'"
    }
}
```

### 模板 F：防卡住超时 wrapper（每条命令的执行容器）

> **最高优先级原语。** agent-browser 命令（尤其 `open`/`wait`）可能因页面加载、连不上目标等卡住数十秒到上百秒，而 agent-browser 自身 timeout 对这些场景不生效。一旦卡住，OpenCode 执行链阻塞，subagent 无法自救。本 wrapper 保证每条命令在设定时间内一定返回。

**为什么不用 Git Bash `timeout` 命令**：实测它发 SIGTERM，**杀不掉** Windows 上的 agent-browser 原生进程。必须用 PowerShell 的 `Start-Process` + `WaitForExit(timeout)` + `taskkill /T /F`。

```powershell
# ===== 防卡住 wrapper 定义（与模板 E 的锁原语一起放在脚本开头）=====
function Invoke-AB {
    param(
        [Parameter(Mandatory)][string]$Session,
        [Parameter(Mandatory)][string[]]$Args,   # agent-browser 子命令及参数，如 @('open','http://...')
        [int]$TimeoutSec = 30                      # 单命令超时上限
    )
    $stdoutLog = "$env:TEMP\ab-$Session-stdout.log"
    $stderrLog = "$env:TEMP\ab-$Session-stderr.log"
    Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

    $allArgs = @('--session', $Session) + $Args
    $proc = Start-Process -FilePath 'agent-browser' -ArgumentList $allArgs `
        -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $proc.WaitForExit($TimeoutSec * 1000) | Out-Null

    if (-not $proc.HasExited) {
        Write-Output "[ab] TIMEOUT after ${TimeoutSec}s — killing CLI (session '$Session', args: $($Args -join ' '))"
        taskkill /pid $proc.Id /T /F 2>$null
        Start-Sleep -Milliseconds 300
        return @{ TimedOut = $true; ExitCode = -1 }
    }

    $stdout = (Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue) ?? ''
    $stderr = (Get-Content $stderrLog -Raw -ErrorAction SilentlyContinue) ?? ''
    if ($stdout.Trim()) { Write-Output $stdout.Trim() }
    return @{ TimedOut = $false; ExitCode = $proc.ExitCode; Stderr = $stderr }
}
```

**使用方式**（替代裸 `agent-browser` 调用）：

```powershell
# 每条命令都经 wrapper 执行，设定合理超时
Invoke-AB -Session 'wallet-qa' -Args @('open','http://localhost:3000/wallet') -TimeoutSec 30
Invoke-AB -Session 'wallet-qa' -Args @('snapshot','-i') -TimeoutSec 15
Invoke-AB -Session 'wallet-qa' -Args @('click','@e3') -TimeoutSec 10
Invoke-AB -Session 'wallet-qa' -Args @('wait','--url','**/success') -TimeoutSec 20
Invoke-AB -Session 'wallet-qa' -Args @('close') -TimeoutSec 10
```

**超时后的衔接**：若某条命令超时（`TimedOut = true`），CLI 被 kill 但 daemon 可能残留为孤儿。此时工作流应**立即跳出**，用模板 B 清理该 session 的残留，然后释放锁——不要继续执行后续命令（daemon 状态已不确定）。

```powershell
$result = Invoke-AB -Session $SESSION -Args @('open',$URL) -TimeoutSec 30
if ($result.TimedOut) {
    Write-Output "[ab] open timed out — cleaning up and releasing lock"
    # 模板 B 的清理逻辑（针对本 session）
    # ... 然后 Release-Lock -Session $SESSION 并 exit 1
}
```

### 模板 A：标准工作流（锁 → wrapper open → 操作 → wrapper close → 验证 → 释放锁）

> 最常用。所有 agent-browser 命令经 `Invoke-AB` wrapper 执行，保证不卡住。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SESSION = "wallet-qa"          # ← 替换: 任务相关且唯一的 session 名
$URL     = "http://127.0.0.1:3000/wallet"  # ← 替换: 目标 URL

# idle timeout 安全网（规则 10）：daemon 空闲 60s 后自动关闭，兜底防"忘了 close / 崩溃残留"
$env:AGENT_BROWSER_IDLE_TIMEOUT_MS = "60000"

# 0. 获取串行化锁（规则 2）— 函数定义见模板 E
if (-not (Acquire-Lock -Session $SESSION -MaxWaitSec 120)) {
    Write-Output "ERROR: could not acquire lock, aborting"
    exit 1
}

try {
    # 1. 打开（命名 session，经 wrapper 防卡住 — 规则 1）
    $r = Invoke-AB -Session $SESSION -Args @('open', $URL) -TimeoutSec 30
    if ($r.TimedOut) { throw "open timed out" }
    $r = Invoke-AB -Session $SESSION -Args @('snapshot', '-i', '-d', '4') -TimeoutSec 15
    # $r = Invoke-AB -Session $SESSION -Args @('click', '@e3') -TimeoutSec 10
    # $r = Invoke-AB -Session $SESSION -Args @('wait', '--url', '**/success') -TimeoutSec 20
    # if ($r.TimedOut) { throw "wait timed out" }

    # 2. 显式关闭（经 wrapper）
    $r = Invoke-AB -Session $SESSION -Args @('close') -TimeoutSec 10
    if ($r.TimedOut) { Write-Output "WARNING: close timed out — daemon may need force kill" }

    # 3. 验证零残留（规则 5）
    Start-Sleep -Milliseconds 500
    $pidFile = "$env:USERPROFILE\.agent-browser\${SESSION}.pid"
    if (Test-Path $pidFile) {
        $daemonPid = (Get-Content $pidFile -Raw).Trim()
        $stillAlive = Get-Process -Id $daemonPid -ErrorAction SilentlyContinue
        if ($stillAlive -and $stillAlive.ProcessName -eq 'agent-browser-win32-x64') {
            Write-Output "WARNING: daemon PID $daemonPid still alive after close; force-killing"
            taskkill /pid $daemonPid /T /F 2>$null
        }
    }
    $pidExists = Test-Path $pidFile
    if (-not $pidExists) {
        Write-Output "closed cleanly: $SESSION"
    } else {
        Write-Output "WARNING: $SESSION sidecar .pid still present (stale file left behind)"
    }
} catch {
    # 超时或异常：清理本 session 残留（模板 B 逻辑），保证锁被释放
    Write-Output "ERROR: $($_.Exception.Message) — cleaning up session residue"
    $pidFile = "$env:USERPROFILE\.agent-browser\${SESSION}.pid"
    if (Test-Path $pidFile) {
        $daemonPid = (Get-Content $pidFile -Raw).Trim()
        $alive = Get-Process -Id $daemonPid -ErrorAction SilentlyContinue
        if ($alive -and $alive.ProcessName -eq 'agent-browser-win32-x64') {
            taskkill /pid $daemonPid /T /F 2>$null
        }
    }
} finally {
    # 4. 释放锁（无论成功失败都必须执行）
    Release-Lock -Session $SESSION
}
```

### 模板 B：精确孤儿清理（基于 sidecar，日常兜底）

> 当 `close` 失效、或怀疑有残留时用。基于 `.pid` sidecar 精确定位，双重安全校验，输出 before/after 计数。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$HOME_DIR = "$env:USERPROFILE\.agent-browser"

# === before 计数 ===
$abBefore = @(Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue).Count
$chromeBefore = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' }).Count
Write-Output "BEFORE: agent-browser daemons=$abBefore  agent-browser chrome=$chromeBefore"

# === 第一类：读 .pid sidecar，清理僵尸/孤儿 daemon ===
$pidFiles = Get-ChildItem "$HOME_DIR\*.pid" -ErrorAction SilentlyContinue
foreach ($pf in $pidFiles) {
    $daemonPid = (Get-Content $pf.FullName -Raw).Trim()
    $proc = Get-Process -Id $daemonPid -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -eq 'agent-browser-win32-x64') {
        Write-Output "Killing daemon PID $daemonPid (session $($pf.BaseName)) — still alive"
        taskkill /pid $daemonPid /T /F 2>$null
    } elseif ($proc) {
        Write-Output "SKIP: PID $daemonPid is alive but NOT agent-browser (is $($proc.ProcessName)) — safety stop"
    } else {
        Write-Output "Stale sidecar: $($pf.Name) -> PID $daemonPid already dead"
    }
}

# === 第二类：扫描残留的 agent-browser Chrome（双重校验）===
# 校验 1: 可执行路径标记（用 .+ 通配分隔符，避免 PowerShell 反斜杠字符类陷阱）
# 校验 2: user-data-dir 含 agent-browser-chrome-
$orphanChrome = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object {
    $_.CommandLine -and
    ($_.CommandLine -match 'agent-browser.+browsers') -and
    ($_.CommandLine -match 'agent-browser-chrome-')
}
foreach ($c in $orphanChrome) {
    # 只杀进程树的根（主进程），避免对已被 /T 覆盖的子进程重复操作；
    # 主进程的特征是没有 --type= 子参数
    if ($c.CommandLine -notmatch '--type=') {
        Write-Output "Killing chrome tree root PID $($c.ProcessId)"
        taskkill /pid $c.ProcessId /T /F 2>$null
    }
}

Start-Sleep -Milliseconds 800

# === after 计数（规则 7）===
$abAfter = @(Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue).Count
$chromeAfter = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' }).Count
Write-Output "AFTER:  agent-browser daemons=$abAfter  agent-browser chrome=$chromeAfter"
if ($abAfter -eq 0 -and $chromeAfter -eq 0) {
    Write-Output "CLEAN: zero residue"
} else {
    Write-Output "WARNING: $abAfter daemon(s) / $chromeAfter chrome(s) remain — run 'agent-browser doctor --fix' or inspect manually"
}
```

### 模板 C：深度清理（sidecar 残留文件 + 临时目录）

> `.engine` 文件会随每次 session 永久堆积。定期用此模板清理"只有 `.engine` 无 `.pid`"的历史残留，以及空的临时 profile 目录。**先列后删**，可加 `-WhatIf` 试跑。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$HOME_DIR = "$env:USERPROFILE\.agent-browser"

# 1. 找出历史残留 .engine（无对应 .pid 的 = 非活跃 session）
$staleEngines = Get-ChildItem "$HOME_DIR\*.engine" -ErrorAction SilentlyContinue | Where-Object {
    -not (Test-Path ($_.FullName -replace '\.engine$', '.pid'))
}
Write-Output "Stale .engine files (no matching .pid): $($staleEngines.Count)"
$staleEngines | ForEach-Object { Write-Output "  $($_.Name)" }

# 2. 清理孤立的 sidecar 残片（有 .port/.stream/.version 但无 .pid 的 = 僵尸遗留）
$orphanSidecars = Get-ChildItem "$HOME_DIR\*.port","$HOME_DIR\*.stream","$HOME_DIR\*.version" -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-Path ($_.FullName -replace '\.(port|stream|version)$', '.pid')) }
if ($orphanSidecars) { Write-Output "Orphan sidecar fragments: $($orphanSidecars.Count)" }

# 3. 清理空的临时 profile 目录
$staleTempDirs = Get-ChildItem $env:TEMP -Directory -Filter 'agent-browser-chrome-*' -ErrorAction SilentlyContinue |
    Where-Object { -not (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue) }
Write-Output "Empty temp profile dirs: $(@($staleTempDirs).Count)"

# === 执行删除（确认无误后去掉 -WhatIf）===
# $staleEngines | Remove-Item -Force -WhatIf
# $orphanSidecars | Remove-Item -Force -WhatIf
# $staleTempDirs | Remove-Item -Recurse -Force -WhatIf
Write-Output "Dry run complete. Remove '-WhatIf' (uncomment above) to actually delete."
```

### 模板 D：卡住诊断（超时恢复后 / 事后排查）

> 在某个 agent-browser 命令超时被 wrapper 杀掉后，或新一轮工作流开始前发现疑似残留时，用此模板定位浏览器进程再决定清理。**注意：真正卡住期间无法调用本模板**（执行链阻塞）——它用于超时恢复后的事后排查，不是实时自救。**绝不盲目杀掉目标端口上的应用进程**——浏览器残留和应用进程无关。

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Output "=== Active agent-browser sessions ==="
agent-browser session list

Write-Output "`n=== Live daemons ==="
Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue |
    Select-Object Id, StartTime | Format-Table -AutoSize

Write-Output "`n=== Sidecar .pid files (live?) ==="
Get-ChildItem "$env:USERPROFILE\.agent-browser\*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    $dpid = (Get-Content $_.FullName -Raw).Trim()
    $alive = if (Get-Process -Id $dpid -ErrorAction SilentlyContinue) { 'LIVE' } else { 'DEAD' }
    Write-Output "  $($_.BaseName): pid=$dpid => $alive"
}

Write-Output "`n=== agent-browser Chrome trees (roots only) ==="
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' -and $_.CommandLine -notmatch '--type=' } |
    Select-Object ProcessId, @{N='ParentProcessId';E={$_.ParentProcessId}} |
    Format-Table -AutoSize

Write-Output "`n=== Distinguish from unrelated port owners (e.g. :3000 target app) ==="
$conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    Write-Output "Port 3000 owner: PID=$($owner.ProcessId) Name=$($owner.Name)"
    Write-Output "  -> This is the TARGET APP the browser is visiting. Do NOT kill it for a browser hang."
}
```

诊断后：若是浏览器残留 → 模板 B 清理。若端口上的应用进程才是问题源，那属于应用进程管理，不在本 skill 范围。

## 反例

```powershell
# ❌ 裸 agent-browser 调用不经 wrapper —— 命令可能卡 138s+，执行链阻塞，subagent 无法自救
agent-browser --session x open http://localhost:3000    # 卡住时整个 session 冻结
# ❌ 也不可用 Git Bash timeout 包裹 —— SIGTERM 杀不掉 Windows 原生进程
timeout 30 agent-browser --session x open http://...    # 无效！进程不会被杀

# ✅ 必须经 Invoke-AB wrapper（Start-Process + WaitForExit + taskkill）
# Invoke-AB -Session x -Args @('open','http://...') -TimeoutSec 30

# ❌ 并发调用无锁 —— 多个 subagent 同时 open 不同 session
# 会导致 session 劫持（#326）、Chrome 静默崩溃（#1378）、孤儿进程堆积
# subagent A: agent-browser --session task-a open http://...
# subagent B: agent-browser --session task-b open http://...   ← 同时！冲突！

# ❌ 裸 open 无 session —— 用了 default session，状态串台，难追踪难清理
agent-browser open http://localhost:3000
agent-browser snapshot -i

# ❌ 忘记 close —— daemon + chrome 永久驻留直到被 bash tool 超时强杀
agent-browser --session x open http://localhost:3000
agent-browser --session x snapshot -i
# (没有 close，也没有释放锁)

# ❌ 只靠 IDLE_TIMEOUT 不主动 close —— 锁无法及时释放给排队者
# idle timeout（0.31+）能兜底回收 daemon，但要等满计时（如 60s），
# 期间锁被占用，其他 subagent 全部阻塞。正确做法：工作完成立即 close 释放锁
agent-browser --session x open http://localhost:3000
# (没有 close，期望 idle timeout 兜底 —— 锁被占满 60s)

# ❌ 按进程名杀 chrome —— 会杀掉用户真实 Chrome
taskkill /im chrome.exe /F
Stop-Process -Name chrome -Force

# ❌ taskkill 不带 /T —— 只杀主进程，Chrome 子进程（renderer/gpu/network）全部变孤儿
taskkill /pid $daemonPid /F    # 缺 /T

# ❌ 杀错对象 —— 浏览器卡住时杀掉目标端口上的应用进程
# (应该先用模板 D 区分浏览器 daemon PID 和被访问应用 PID)

# ❌ PowerShell 正则用 [\\/] 匹配反斜杠路径 —— 实测对 \ 失败，校验静默失效
# Where-Object { $_.CommandLine -match '\.agent-browser[\\/]browsers' }   ← 永远 False！
# ✅ 用 agent-browser.+browsers（. 通配分隔符）

# ✅ 正确姿势：wrapper 防卡住 + 锁 + 命名 session + 显式 close + 验证 + 释放锁（模板 A + E + F）
# Acquire-Lock -Session wallet-qa
# Invoke-AB -Session wallet-qa -Args @('open','http://localhost:3000/wallet') -TimeoutSec 30
# Invoke-AB -Session wallet-qa -Args @('snapshot','-i') -TimeoutSec 15
# Invoke-AB -Session wallet-qa -Args @('close') -TimeoutSec 10
# + 模板 A 的验证段 + Release-Lock
```

## 收尾顺序

浏览器操作常涉及访问某个本地端口上的应用。收尾时必须**先 close 浏览器，再由该应用自身的进程管理停止应用**——顺序反了会导致浏览器 `wait` 命令卡在已关闭的端口上，制造新的卡住。本 skill 只负责浏览器侧的 close + 验证 + 锁释放（模板 A），应用进程的启停不在本 skill 范围。

## 最小触发词

- 主要：`agent-browser`、`open url`、`snapshot`、`click @e`、`screenshot`、`浏览器`、`Chrome 残留`、`tool call 卡 running`、`close --all`、`session list`、`smoke test`、`E2E`、`QA`
- 次要：`daemon`、`sidecar`、`.engine`、`.pid`、`agent-browser-win32-x64`、`agent-browser-chrome-`、`orphan`、`孤儿进程`、`headless chrome`

## 平台事实

| 参数 | 值 |
|------|-----|
| 范围 | Windows（PowerShell 7+ / Git Bash） |
| CLI 版本基准 | agent-browser 0.31.2（行为已验证；0.29.1 的 idle timeout bug 已修） |
| CLI 路径 | `C:\Users\Administrator\.bun\bin\agent-browser.exe` |
| 原生二进制 | `agent-browser-win32-x64.exe`（daemon 进程名） |
| 状态目录 | `C:\Users\Administrator\.agent-browser\`（sidecar 5 件套） |
| Chrome 路径 | `C:\Users\Administrator\.agent-browser\browsers\chrome-<ver>\chrome.exe` |
| Chrome user-data-dir | `%TEMP%\agent-browser-chrome-<GUID>`（每次随机） |
| 默认 action timeout | 25000ms（`AGENT_BROWSER_DEFAULT_TIMEOUT`）——但对 `open`/页面加载不生效 |
| open 卡住实测 | 连不上目标时 Chrome 导航超时可达 138s+；agent-browser 自身 timeout 不覆盖此场景 |
| Git Bash `timeout` 命令 | **无效**——发 SIGTERM 杀不掉 Windows 原生进程；必须用 PowerShell `Start-Process`+`taskkill` |
| 防卡住 wrapper | `Invoke-AB`（模板 F）：`Start-Process` + `WaitForExit(timeout)` + 超时 `taskkill /T /F` |
| `IDLE_TIMEOUT_MS`（0.31+） | 已生效：设值后 daemon 空闲超时自动关闭并清理 Chrome；推荐设 60000 作安全网 |
| `close --all` | 只清 sidecar 关联的 daemon；强杀后的孤儿清不掉 |
| `doctor --fix` | 有效但过重（含网络检查 + launch test） |
| 串行化锁文件 | `%TEMP%\agent-browser-global.lock`（内容 `SESSION=<name>` + 时间戳） |
| 锁原子性 | `[System.IO.File]::Open` + `FileMode.CreateNew`（无 TOCTOU 竞态） |
| 并发官方 issue | #326 session 劫持、#1378 Chrome 静默崩溃、#885 lock-based 方案 |
| Windows kill 进程树 | `taskkill /pid <PID> /T /F`（`/T` 必须有，否则 Chrome 子进程变孤儿） |
