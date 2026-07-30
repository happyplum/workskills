<#
.SYNOPSIS
  限时前台捕获（运行 N 秒 → 捕获 tail → 杀死）
.DESCRIPTION
  与 start-background 相同：WMI supervisor + ArgumentList。用于 E2E smoke，不用于常驻 dev server。
.PARAMETER Exe
  可执行文件名（PATH 中）
.PARAMETER CommandArgs
  参数数组
.PARAMETER TimeoutSec
  捕获时长（秒）
.PARAMETER LogPrefix
  日志前缀
.PARAMETER Dir
  工作目录（默认当前目录）
.EXAMPLE
  .\capture-timed.ps1 -Exe flutter -CommandArgs @('run','-d','chrome') -TimeoutSec 90 -LogPrefix flutter -Dir .
#>
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string[]]$CommandArgs,
    [Parameter(Mandatory)][int]$TimeoutSec,
    [Parameter(Mandatory)][string]$LogPrefix,
    [string]$Dir = '.'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\common.ps1"

$workDir = (Resolve-Path -LiteralPath $Dir).Path
try {
    $resolved = (Get-Command $Exe -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $Exe not found"; exit 1
}

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$safePrefix = ($LogPrefix -replace '[^A-Za-z0-9._-]', '_')
$RunId = "capture-$safePrefix-$stamp-$PID"
$stateRoot = Get-LrpStateRoot
$stdoutLog = Join-Path $stateRoot "$RunId-stdout.log"
$stderrLog = Join-Path $stateRoot "$RunId-stderr.log"
$statePath = Get-LrpStatePath -RunId $RunId
$configPath = Join-Path $stateRoot "$RunId-config.json"
$supervisor = Join-Path $PSScriptRoot 'supervisor-run.ps1'

$state = [ordered]@{
    RunId      = $RunId
    ControlPid = 0
    AppPid     = 0
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    WorkDir    = $workDir
    Exe        = $resolved
    Args       = @($CommandArgs)
    Port       = 0
    StdoutLog  = $stdoutLog
    StderrLog  = $stderrLog
    StatePath  = $statePath
}
Write-LrpState -State $state | Out-Null

$config = [ordered]@{
    Exe       = $resolved
    Args      = @($CommandArgs)
    WorkDir   = $workDir
    StdoutLog = $stdoutLog
    StderrLog = $stderrLog
    StatePath = $statePath
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 6), $utf8)

$psExe = $null
foreach ($candidate in @(
        "${env:ProgramFiles}\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles}\PowerShell\7-preview\pwsh.exe"
    )) {
    if (Test-Path -LiteralPath $candidate) { $psExe = $candidate; break }
}
if (-not $psExe) {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { $psExe = $cmd.Source }
}
if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction Stop).Source }

$launcherPath = Join-Path $stateRoot "$RunId-launch.cmd"
$launchLines = @(
    '@echo off'
    '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}"' -f $psExe, $supervisor, $configPath
)
[System.IO.File]::WriteAllLines($launcherPath, $launchLines, [System.Text.Encoding]::ASCII)

$wmiCmd = '"{0}" /d /c "{1}"' -f $env:ComSpec, $launcherPath
$startup = ([wmiclass]'Win32_ProcessStartup').CreateInstance()
$startup.ShowWindow = 0
$result = ([wmiclass]'Win32_Process').Create($wmiCmd, $stateRoot, $startup)
if ($result.ReturnValue -ne 0) {
    Write-Output "ERROR: Win32_Process.Create failed with code $($result.ReturnValue)"; exit 1
}

$controlPid = [int]$result.ProcessId
$state.ControlPid = $controlPid
$state.LauncherPath = $launcherPath
Write-LrpState -State $state | Out-Null
Write-Output "RunId: $RunId"
Write-Output "ControlPid: $controlPid"

$elapsed = 0
$appPid = 0
while ($elapsed -lt $TimeoutSec) {
    try {
        $latest = Read-LrpState -RunId $RunId
        if ([int]$latest.AppPid -gt 0) { $appPid = [int]$latest.AppPid }
    } catch { }

    $controlAlive = Test-LrpProcessAlive -ProcessId $controlPid
    $appAlive = ($appPid -gt 0) -and (Test-LrpProcessAlive -ProcessId $appPid)
    if (-not $controlAlive -and -not $appAlive) {
        Write-Output 'Process exited naturally'
        break
    }
    Start-Sleep 2
    $elapsed += 2
}

if ($elapsed -ge $TimeoutSec) {
    $killTarget = if (Test-LrpProcessAlive -ProcessId $controlPid) { $controlPid } elseif ($appPid -gt 0) { $appPid } else { 0 }
    if ($killTarget -gt 0) {
        $tk = Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/pid', "$killTarget", '/T', '/F') -Wait -PassThru -NoNewWindow
        Write-Output "Process tree killed after ${TimeoutSec}s (root=$killTarget exit=$($tk.ExitCode))"
    }
}

if ($appPid -gt 0) { Write-Output "AppPid: $appPid" }
$stdoutTail = Get-Content -LiteralPath $stdoutLog -Tail 50 -ErrorAction SilentlyContinue
$stderrTail = Get-Content -LiteralPath $stderrLog -Tail 50 -ErrorAction SilentlyContinue
Write-Output "Last stdout:`n$(($stdoutTail) -join "`n")"
Write-Output "Last stderr:`n$(($stderrTail) -join "`n")"
