<#
.SYNOPSIS
  agent-browser 会话安全开启（锁 + open，失败自动清理）
.DESCRIPTION
  工作流第一步：设置 idle timeout → Acquire-Lock → Invoke-AB open。
  open 失败或超时则清理该 session 残留 + 释放锁 + exit 1。
  成功后调用方用 Invoke-AB 执行业务步骤，最后调 close-session.ps1 收尾。
  必须与 close-session.ps1 配对（同一 session 名）。
  来自 agent-browser-windows skill 模板 A 前半段。
.PARAMETER Session
  任务相关且唯一的 session 名
.PARAMETER Url
  目标 URL
.PARAMETER MaxWaitSec
  锁等待上限（秒），默认 120
.PARAMETER OpenTimeoutSec
  open 命令超时（秒），默认 30
.EXAMPLE
  .\open-session.ps1 -Session wallet-qa -Url http://127.0.0.1:3000/wallet
#>
param(
    [Parameter(Mandatory)][string]$Session,
    [Parameter(Mandatory)][string]$Url,
    [int]$MaxWaitSec = 120,
    [int]$OpenTimeoutSec = 30
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ab-primitives.ps1"

$env:AGENT_BROWSER_IDLE_TIMEOUT_MS = "60000"   # idle timeout 安全网（规则 10）

if (-not (Acquire-Lock -Session $Session -MaxWaitSec $MaxWaitSec)) {
    Write-Output "ERROR: could not acquire lock for session '$Session'"
    exit 1
}

try {
    $r = Invoke-AB -Session $Session -ABArgs @('open', $Url) -TimeoutSec $OpenTimeoutSec
    if ($r.TimedOut) { throw "open timed out after ${OpenTimeoutSec}s" }
    Write-Output "[open-session] ready: session='$Session' url='$Url'"
} catch {
    Write-Output "ERROR: $_"
    # open 失败 — 清理该 session 残留 daemon + 释放锁
    $pidFile = "$env:USERPROFILE\.agent-browser\${Session}.pid"
    if (Test-Path $pidFile) {
        $dpid = (Get-Content $pidFile -Raw).Trim()
        $alive = Get-Process -Id $dpid -ErrorAction SilentlyContinue
        if ($alive -and $alive.ProcessName -eq 'agent-browser-win32-x64') { taskkill /pid $dpid /T /F 2>$null }
    }
    Release-Lock -Session $Session
    exit 1
}
