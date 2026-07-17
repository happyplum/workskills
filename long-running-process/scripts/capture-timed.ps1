<#
.SYNOPSIS
  限时前台捕获（运行 N 秒 → 捕获 → 杀死）
.DESCRIPTION
  运行进程至超时或自然退出，捕获 stdout/stderr tail。
  仅用于需要运行 N 秒捕获启动状态的场景（如 E2E smoke test）。
  不要用于需持续运行的 QA dev server——用 start-background + wait-ready。
  来自 long-running-process skill 模板 3。
.PARAMETER Exe
  可执行文件名（需在 PATH 中）
.PARAMETER CommandArgs
  命令参数数组，如 @('run','-d','chrome','--web-port=8234')
.PARAMETER TimeoutSec
  捕获时长（秒）
.PARAMETER LogPrefix
  日志文件前缀
.EXAMPLE
  .\capture-timed.ps1 -Exe flutter -CommandArgs @('run','-d','chrome','--web-port=8234') -TimeoutSec 90 -LogPrefix flutter
#>
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string[]]$CommandArgs,
    [Parameter(Mandatory)][int]$TimeoutSec,
    [Parameter(Mandatory)][string]$LogPrefix
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stdoutLog = "$env:TEMP\${LogPrefix}-stdout-$PID.log"
$stderrLog = "$env:TEMP\${LogPrefix}-stderr-$PID.log"

try {
    $resolved = (Get-Command $Exe -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $Exe not found"; exit 1
}

# WMI 启动降低 pipe 句柄泄漏风险（同 start-background）
$launcher = "$env:TEMP\${LogPrefix}-launch-$PID.cmd"
@"
@echo off
"$resolved" $($CommandArgs -join ' ') 1>"$stdoutLog" 2>"$stderrLog" <NUL
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
while ($elapsed -lt $TimeoutSec) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) {
        Write-Output "Process exited naturally"
        break
    }
    Start-Sleep 2; $elapsed += 2
}
if ($elapsed -ge $TimeoutSec) {
    taskkill /pid $procId /T /F 2>$null
    Write-Output "Process tree killed after ${TimeoutSec}s"
}

$stdoutTail = Get-Content -LiteralPath $stdoutLog -Tail 50 -ErrorAction SilentlyContinue
$stderrTail = Get-Content -LiteralPath $stderrLog -Tail 50 -ErrorAction SilentlyContinue
Write-Output "Last stdout:`n$(($stdoutTail) -join "`n")"
Write-Output "Last stderr:`n$(($stderrTail) -join "`n")"
