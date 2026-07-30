<#
.SYNOPSIS
  长运行后台进程安全启动（Windows / PowerShell 7+）
.DESCRIPTION
  WMI 启动 PowerShell supervisor；supervisor 用 ProcessStartInfo.ArgumentList 启应用。
  输出 RunId / ControlPid / AppPid / state / logs。可选端口占用检查。
.PARAMETER Pm
  包管理器或可执行文件，如 pnpm.cmd / npm.cmd / flutter / cargo
.PARAMETER CommandArgs
  参数数组（字面传递，勿拼成单字符串）
.PARAMETER Port
  可选：预期监听端口（启动前占用检查）
.PARAMETER Dir
  工作目录
.PARAMETER LogPrefix
  日志/RunId 前缀
.PARAMETER RunId
  可选；默认自动生成
.EXAMPLE
  .\start-background.ps1 -Pm pnpm.cmd -CommandArgs @('dev') -Port 3000 -Dir 'C:\proj' -LogPrefix dev
#>
param(
    [Parameter(Mandatory)][string]$Pm,
    [Parameter(Mandatory)][string[]]$CommandArgs,
    [int]$Port = 0,
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$LogPrefix,
    [string]$RunId = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\common.ps1"

$workDir = (Resolve-Path -LiteralPath $Dir).Path
if ($Port -gt 0) {
    $owners = Get-LrpListenersOnPort -Port $Port
    if ($owners.Count -gt 0) {
        $details = foreach ($op in $owners) {
            Get-CimInstance Win32_Process -Filter "ProcessId=$op" -ErrorAction SilentlyContinue |
                Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
        }
        Write-Output "ERROR: Port $Port already in use.`n$($details -join "`n")"
        exit 1
    }
}

try {
    $exe = (Get-Command $Pm -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $Pm not found; install or fix PATH"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    $safePrefix = ($LogPrefix -replace '[^A-Za-z0-9._-]', '_')
    $RunId = "$safePrefix-$stamp-$PID"
}
if ($RunId -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Output "ERROR: Invalid RunId: $RunId"
    exit 1
}

$stateRoot = Get-LrpStateRoot
$stdoutLog = Join-Path $stateRoot "$RunId-stdout.log"
$stderrLog = Join-Path $stateRoot "$RunId-stderr.log"
$statePath = Get-LrpStatePath -RunId $RunId
$configPath = Join-Path $stateRoot "$RunId-config.json"
$supervisor = Join-Path $PSScriptRoot 'supervisor-run.ps1'

$state = [ordered]@{
    RunId          = $RunId
    ControlPid     = 0
    AppPid         = 0
    CreatedUtc     = [DateTime]::UtcNow.ToString('o')
    AppStartedUtc  = $null
    WorkDir        = $workDir
    Exe            = $exe
    Args           = @($CommandArgs)
    Port           = $Port
    StdoutLog      = $stdoutLog
    StderrLog      = $stderrLog
    StatePath      = $statePath
    ConfigPath     = $configPath
    SupervisorPath = $supervisor
}
Write-LrpState -State $state | Out-Null

$config = [ordered]@{
    Exe       = $exe
    Args      = @($CommandArgs)
    WorkDir   = $workDir
    StdoutLog = $stdoutLog
    StderrLog = $stderrLog
    StatePath = $statePath
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 6), $utf8)

# 优先固定安装路径，避免 WindowsApps 别名异常
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

# 本机实测：WMI 直接 Create pwsh 往往立即退出；须经 cmd 启动。
# .cmd 仅含 ASCII 路径（ps/supervisor/config）；用户参数与 Unicode WorkDir 只在 UTF-8 JSON 中。
$launcherPath = Join-Path $stateRoot "$RunId-launch.cmd"
$launchLines = @(
    '@echo off'
    '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}"' -f $psExe, $supervisor, $configPath
)
# cmd 脚本本身保持 ASCII（路径均在 Program Files / TEMP / 用户 ASCII 配置目录）
[System.IO.File]::WriteAllLines($launcherPath, $launchLines, [System.Text.Encoding]::ASCII)

$wmiCmd = '"{0}" /d /c "{1}"' -f $env:ComSpec, $launcherPath
$startup = ([wmiclass]'Win32_ProcessStartup').CreateInstance()
$startup.ShowWindow = 0
$result = ([wmiclass]'Win32_Process').Create($wmiCmd, $stateRoot, $startup)
if ($result.ReturnValue -ne 0) {
    Write-Output "ERROR: Win32_Process.Create failed with code $($result.ReturnValue)"
    exit 1
}

$controlPid = [int]$result.ProcessId
$state.ControlPid = $controlPid
$state.SupervisorExe = $psExe
$state.LauncherPath = $launcherPath
Write-LrpState -State $state | Out-Null

$bootLog = "$configPath.boot.log"
# 等待 AppPid 回写或 control 死亡
$deadline = [DateTime]::UtcNow.AddSeconds(8)
$appPid = 0
while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $latest = Read-LrpState -RunId $RunId
        if ([int]$latest.AppPid -gt 0) {
            $appPid = [int]$latest.AppPid
            break
        }
    } catch { }
    if (-not (Test-LrpProcessAlive -ProcessId $controlPid)) {
        $boot = if (Test-Path -LiteralPath $bootLog) { Get-Content -LiteralPath $bootLog -Raw } else { '(no boot log)' }
        $errTail = Get-Content -LiteralPath $stderrLog -Tail 20 -ErrorAction SilentlyContinue
        Write-Output "ERROR: ControlPid $controlPid died before AppPid was recorded.`nBoot log:`n$boot`nLast stderr:`n$errTail"
        exit 1
    }
    Start-Sleep -Milliseconds 200
}

if ($appPid -le 0) {
    $boot = if (Test-Path -LiteralPath $bootLog) { Get-Content -LiteralPath $bootLog -Raw } else { '(no boot log)' }
    Write-Output "ERROR: AppPid not recorded within 8s. ControlPid=$controlPid State=$statePath`nBoot log:`n$boot"
    exit 1
}

if (-not (Test-LrpProcessAlive -ProcessId $appPid) -and -not (Test-LrpProcessAlive -ProcessId $controlPid)) {
    $errTail = Get-Content -LiteralPath $stderrLog -Tail 20 -ErrorAction SilentlyContinue
    Write-Output "ERROR: Process tree died immediately. ControlPid=$controlPid AppPid=$appPid`nLast stderr:`n$errTail"
    exit 1
}

Write-Output "RunId: $RunId"
Write-Output "ControlPid: $controlPid"
Write-Output "AppPid: $appPid"
Write-Output "State: $statePath"
Write-Output "Logs: $stdoutLog / $stderrLog"
if ($Port -gt 0) {
    Write-Output "Port: $Port (not ready yet — call wait-ready.ps1 -RunId $RunId)"
}
