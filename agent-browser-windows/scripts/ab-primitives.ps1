<#
.SYNOPSIS
  agent-browser 串行化锁原语 + 防卡住超时 wrapper（dot-source 模块）
.DESCRIPTION
  定义 agent-browser Windows 进程安全的核心原语。使用前 dot-source：
    . <skill-dir>/scripts/ab-primitives.ps1
  然后调用 Acquire-Lock / Release-Lock / Invoke-AB。
  来自 agent-browser-windows skill 模板 E（锁）+ 模板 F（wrapper）。
.NOTES
  锁语义：绑定 session 名（不绑定 bash PID，因每次 Bash 调用是独立进程）。
  原子获取用 FileMode.CreateNew（无 TOCTOU 竞态）。持有者 daemon 死亡则抢占陈旧锁。
  Invoke-AB 保证每条 agent-browser 命令在设定时间内返回（open/wait 可卡 138s+）。
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ===== 常量 =====
$global:AB_LOCK_PATH = "$env:TEMP\agent-browser-global.lock"
$global:AB_HOME_DIR  = "$env:USERPROFILE\.agent-browser"

# ===== 锁原语 =====

function Test-SessionDaemonAlive {
    # 通过 .pid sidecar 判断某 session 的 daemon 是否存活
    param([Parameter(Mandatory)][string]$SessionName)
    $pidFile = Join-Path $AB_HOME_DIR "$SessionName.pid"
    if (-not (Test-Path $pidFile)) { return $false }
    $dpid = (Get-Content $pidFile -Raw).Trim()
    $proc = Get-Process -Id $dpid -ErrorAction SilentlyContinue
    return ($null -ne $proc -and $proc.ProcessName -eq 'agent-browser-win32-x64')
}

function Get-LockHolder {
    # 读锁文件里的 session 名（用 -replace 提取，避免正则陷阱）
    if (-not (Test-Path $AB_LOCK_PATH)) { return $null }
    $line = (Get-Content $AB_LOCK_PATH -ErrorAction SilentlyContinue) |
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
            $fs = [System.IO.File]::Open($AB_LOCK_PATH,
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
                Remove-Item $AB_LOCK_PATH -Force -ErrorAction SilentlyContinue
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
    if (-not (Test-Path $AB_LOCK_PATH)) {
        Write-Output "[lock] no lock file to release"
        return
    }
    $holder = Get-LockHolder
    if ($holder -eq $Session) {
        Remove-Item $AB_LOCK_PATH -Force
        Write-Output "[lock] released by session '$Session'"
    } else {
        # 不删别人的锁 — 只报告
        Write-Output "[lock] SKIP release: owned by '$holder', not '$Session'"
    }
}

# ===== 防卡住超时 wrapper =====

function Invoke-AB {
    <#
    agent-browser 命令的防卡住执行容器。
    open/wait 可能因页面加载卡 138s+，agent-browser 自身 timeout 不覆盖此场景。
    本 wrapper 保证命令在设定时间内返回。不可用 Git Bash timeout（发 SIGTERM 杀不掉 Windows 原生进程）。
    #>
    param(
        [Parameter(Mandatory)][string]$Session,
        [Parameter(Mandatory)][string[]]$ABArgs,
        [int]$TimeoutSec = 30
    )
    $stdoutLog = "$env:TEMP\ab-$Session-stdout.log"
    $stderrLog = "$env:TEMP\ab-$Session-stderr.log"
    Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

    $allArgs = @('--session', $Session) + $ABArgs
    $proc = Start-Process -FilePath 'agent-browser' -ArgumentList $allArgs `
        -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $proc.WaitForExit($TimeoutSec * 1000) | Out-Null

    if (-not $proc.HasExited) {
        Write-Output "[ab] TIMEOUT after ${TimeoutSec}s — killing CLI (session '$Session', args: $($ABArgs -join ' '))"
        taskkill /pid $proc.Id /T /F 2>$null
        Start-Sleep -Milliseconds 300
        return @{ TimedOut = $true; ExitCode = -1 }
    }

    $stdout = (Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue) ?? ''
    $stderr = (Get-Content $stderrLog -Raw -ErrorAction SilentlyContinue) ?? ''
    if ($stdout.Trim()) { Write-Output $stdout.Trim() }
    return @{ TimedOut = $false; ExitCode = $proc.ExitCode; Stderr = $stderr }
}
