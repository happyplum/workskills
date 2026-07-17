<#
.SYNOPSIS
  agent-browser 会话安全关闭（验证零残留 + close + 释放锁）
.DESCRIPTION
  工作流最后一步：Invoke-AB close → 验证本 session 无残留 daemon → Release-Lock。
  验证与锁释放在 finally 块中，即使 close 命令本身失败也会兜底执行。
  必须与 open-session.ps1 配对（同一 session 名）。
  来自 agent-browser-windows skill 模板 A 后半段。
.PARAMETER Session
  与 open-session 相同的 session 名
.PARAMETER CloseTimeoutSec
  close 命令超时（秒），默认 10
.EXAMPLE
  .\close-session.ps1 -Session wallet-qa
#>
param(
    [Parameter(Mandatory)][string]$Session,
    [int]$CloseTimeoutSec = 10
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ab-primitives.ps1"

try {
    Invoke-AB -Session $Session -ABArgs @('close') -TimeoutSec $CloseTimeoutSec | Out-Null
} finally {
    # 验证零残留（规则 5）— 即使 close 命令失败也要兜底清理 + 释放锁
    Start-Sleep -Milliseconds 500
    $pidFile = "$env:USERPROFILE\.agent-browser\${Session}.pid"
    if (Test-Path $pidFile) {
        $dpid = (Get-Content $pidFile -Raw).Trim()
        $alive = Get-Process -Id $dpid -ErrorAction SilentlyContinue
        if ($alive -and $alive.ProcessName -eq 'agent-browser-win32-x64') {
            Write-Output "[close-session] killing residual daemon PID $dpid"
            taskkill /pid $dpid /T /F 2>$null
        }
    }
    Release-Lock -Session $Session
}
Write-Output "[close-session] done: session='$Session' lock released"
