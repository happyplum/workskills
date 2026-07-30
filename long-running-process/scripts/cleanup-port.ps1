<#
.SYNOPSIS
  清理占用指定端口的进程（精确匹配，防误杀）
.DESCRIPTION
  枚举该端口全部 listener；仅当唯一 owner 且命令行匹配 RequireMatch 时 taskkill /T /F。
  多 owner 或归属歧义时拒绝。
.PARAMETER Port
  端口号
.PARAMETER RequireMatch
  命令行必须包含的子串（绝对项目路径或唯一标记；勿用 node/pnpm 裸名）
.EXAMPLE
  .\cleanup-port.ps1 -Port 3000 -RequireMatch "my-project\node_modules"
#>
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$RequireMatch
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\common.ps1"

$owners = Get-LrpListenersOnPort -Port $Port
if ($owners.Count -eq 0) {
    Write-Output "Port $Port is free"
    exit 0
}

if ($owners.Count -gt 1) {
    $info = foreach ($op in $owners) {
        Get-CimInstance Win32_Process -Filter "ProcessId=$op" -ErrorAction SilentlyContinue |
            Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
    }
    Write-Output "ERROR: Port $Port has multiple listeners ($($owners -join ',')). Refusing ambiguous cleanup.`n$($info -join "`n")"
    exit 1
}

$pidToKill = [int]$owners[0]
$owner = Get-CimInstance Win32_Process -Filter "ProcessId=$pidToKill" -ErrorAction SilentlyContinue
if (-not $owner) {
    Write-Output "ERROR: Owning process $pidToKill not found. Refusing cleanup."
    exit 1
}

$ownerInfo = $owner | Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
Write-Output "Candidate owner:`n$ownerInfo"

$commandLine = [string]$owner.CommandLine
$normalizedCmd = $commandLine.Replace('/', '\')
$normalizedMatch = $RequireMatch.Replace('/', '\')
if ([string]::IsNullOrEmpty($commandLine) -or
    ($normalizedCmd.IndexOf($normalizedMatch, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
    Write-Output "ERROR: PID $pidToKill does not match RequireMatch '$RequireMatch'. Refusing cleanup."
    exit 1
}

$tk = Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/pid', "$pidToKill", '/T', '/F') -Wait -PassThru -NoNewWindow
if ($tk.ExitCode -ne 0 -and $tk.ExitCode -ne 128) {
    Write-Output "ERROR: taskkill exit $($tk.ExitCode) for PID $pidToKill"
    exit 1
}

Start-Sleep -Milliseconds 400
$still = Get-LrpListenersOnPort -Port $Port
if ($still.Count -gt 0) {
    Write-Output "ERROR: Port $Port still has listeners after kill: $($still -join ',')"
    exit 1
}

Write-Output "Killed process tree for PID $pidToKill; port $Port is free"
