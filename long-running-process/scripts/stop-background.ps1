<#
.SYNOPSIS
  按 RunId 停止 start-background 启动的进程树并验证
.PARAMETER RunId
  start-background 输出的 RunId
.PARAMETER RequirePortFree
  若 state 含 Port，停止后验证端口已释放
.EXAMPLE
  .\stop-background.ps1 -RunId dev-20260101-1
#>
param(
    [Parameter(Mandatory)][string]$RunId,
    [switch]$RequirePortFree
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\common.ps1"

$state = Read-LrpState -RunId $RunId
$controlPid = [int]$state.ControlPid
$appPid = [int]$state.AppPid
$port = 0
if ($state.PSObject.Properties.Name -contains 'Port' -and $state.Port) {
    $port = [int]$state.Port
}

$controlAlive = Test-LrpProcessAlive -ProcessId $controlPid
$appAlive = ($appPid -gt 0) -and (Test-LrpProcessAlive -ProcessId $appPid)

if (-not $controlAlive -and -not $appAlive) {
    Write-Output "Already stopped: RunId=$RunId ControlPid=$controlPid AppPid=$appPid"
} else {
    # ControlPid 可能是 cmd 包装进程；校验 launcher 路径 / RunId / supervisor
    if ($controlAlive) {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$controlPid" -ErrorAction SilentlyContinue
        $cl = if ($proc) { [string]$proc.CommandLine } else { '' }
        $launcher = ''
        if ($state.PSObject.Properties.Name -contains 'LauncherPath') { $launcher = [string]$state.LauncherPath }
        $looksOurs = $false
        if ($cl -match 'supervisor-run\.ps1') { $looksOurs = $true }
        if ($launcher -and $cl.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $looksOurs = $true }
        if ($cl.IndexOf($RunId, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $looksOurs = $true }
        if ($cl -match 'cmd\.exe' -and $launcher -and (Test-Path -LiteralPath $launcher)) { $looksOurs = $true }
        if (-not $looksOurs) {
            Write-Output "ERROR: ControlPid $controlPid does not look like this run. Refusing stop.`n$cl"
            exit 1
        }
        $killTarget = $controlPid
    } else {
        $killTarget = $appPid
    }

    $tk = Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/pid', "$killTarget", '/T', '/F') -Wait -PassThru -NoNewWindow
    if ($tk.ExitCode -ne 0 -and $tk.ExitCode -ne 128) {
        # 128 = 进程未找到
        Write-Output "ERROR: taskkill exit $($tk.ExitCode) for PID $killTarget"
        exit 1
    }

    Start-Sleep -Milliseconds 400
    if ((Test-LrpProcessAlive -ProcessId $controlPid) -or (($appPid -gt 0) -and (Test-LrpProcessAlive -ProcessId $appPid))) {
        Write-Output "ERROR: Process tree still alive after taskkill (ControlPid=$controlPid AppPid=$appPid)"
        exit 1
    }
    Write-Output "Stopped RunId=$RunId (killed tree root PID $killTarget)"
}

if ($RequirePortFree -or $port -gt 0) {
    if ($port -gt 0) {
        $owners = Get-LrpListenersOnPort -Port $port
        if ($owners.Count -gt 0) {
            # 仅当我们的树还占着才算失败；外来占用单独报告
            $ours = @($owners | Where-Object {
                    Test-LrpPidInControlTree -CandidatePid ([int]$_) -ControlPid $controlPid -AppPid $appPid
                })
            if ($ours.Count -gt 0) {
                Write-Output "ERROR: Port $port still owned by this run after stop: $($ours -join ',')"
                exit 1
            }
            if ($RequirePortFree) {
                Write-Output "ERROR: Port $port still in use by other PIDs: $($owners -join ',')"
                exit 1
            }
            Write-Output "WARN: Port $port still in use by other PIDs: $($owners -join ',')"
        } else {
            Write-Output "Port $port is free"
        }
    }
}

$stateOut = [ordered]@{}
foreach ($p in $state.PSObject.Properties) {
    $stateOut[$p.Name] = $p.Value
}
$stateOut['StoppedUtc'] = [DateTime]::UtcNow.ToString('o')
Write-LrpState -State $stateOut | Out-Null
Write-Output "State updated: $(Get-LrpStatePath -RunId $RunId)"
