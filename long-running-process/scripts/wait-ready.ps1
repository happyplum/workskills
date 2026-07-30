<#
.SYNOPSIS
  就绪检查（端口 / health，有界；可选 RunId 归属校验）
.DESCRIPTION
  与 start-background 分两个独立 shell tool 调用。提供 -RunId 时，端口 listener 必须属于该 run 的 control 树。
.PARAMETER Port
  待检查端口（无 HealthUrl 时必填；有 RunId 时可从 state 读取）
.PARAMETER MaxWait
  最大等待秒数；须满足 MaxWait + cleanup margin < 本次显式 outer timeout
.PARAMETER HealthUrl
  可选 health endpoint
.PARAMETER RunId
  可选；提供时校验 listener 归属本 run
.EXAMPLE
  .\wait-ready.ps1 -RunId dev-20260101-1 -MaxWait 60
  .\wait-ready.ps1 -Port 3000 -MaxWait 60
#>
param(
    [int]$Port = 0,
    [Parameter(Mandatory)][int]$MaxWait,
    [string]$HealthUrl = '',
    [string]$RunId = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\common.ps1"

$controlPid = 0
$appPid = 0
if (-not [string]::IsNullOrWhiteSpace($RunId)) {
    $state = Read-LrpState -RunId $RunId
    $controlPid = [int]$state.ControlPid
    $appPid = [int]$state.AppPid
    if ($Port -le 0 -and $state.Port) { $Port = [int]$state.Port }
    if (-not (Test-LrpProcessAlive -ProcessId $controlPid) -and -not (Test-LrpProcessAlive -ProcessId $appPid)) {
        Write-Output "ERROR: RunId=$RunId process tree is not alive (ControlPid=$controlPid AppPid=$appPid)"
        exit 1
    }
}

if ($Port -le 0 -and [string]::IsNullOrWhiteSpace($HealthUrl)) {
    Write-Output 'ERROR: Provide -Port and/or -HealthUrl (or -RunId with Port in state)'
    exit 1
}

$timer = 0
while ($timer -lt $MaxWait) {
    $healthOk = $false
    if (-not [string]::IsNullOrWhiteSpace($HealthUrl)) {
        try {
            $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
                $healthOk = $true
            }
        } catch { }
    }

    $portOk = $true
    $ownerInfo = ''
    if ($Port -gt 0) {
        $owners = Get-LrpListenersOnPort -Port $Port
        if ($owners.Count -eq 0) {
            $portOk = $false
        } elseif ($controlPid -gt 0) {
            $foreign = [System.Collections.Generic.List[int]]::new()
            $owned = [System.Collections.Generic.List[int]]::new()
            foreach ($op in $owners) {
                $opId = [int]$op
                if (Test-LrpPidInControlTree -CandidatePid $opId -ControlPid $controlPid -AppPid $appPid) {
                    $owned.Add($opId) | Out-Null
                } else {
                    $foreign.Add($opId) | Out-Null
                }
            }
            if ($foreign.Count -gt 0 -or $owned.Count -eq 0) {
                $portOk = $false
                if ($foreign.Count -gt 0 -and $timer -ge ($MaxWait - 2)) {
                    Write-Output "ERROR: Port $Port has listener(s) not owned by RunId=$RunId : $($foreign -join ',')"
                    exit 1
                }
            } else {
                $ownerInfo = "owned PIDs $($owned -join ',')"
            }
        } else {
            # 无 RunId：仅报告首个 listener，不能证明归属
            $ownerInfo = "PID $($owners[0]) (ownership not verified — pass -RunId)"
        }
    }

    if ($portOk -and ([string]::IsNullOrWhiteSpace($HealthUrl) -or $healthOk)) {
        if ($healthOk -and $Port -gt 0) {
            Write-Output "Ready: health ok; port $Port ($ownerInfo)"
        } elseif ($healthOk) {
            Write-Output 'Ready: health check passed'
        } else {
            Write-Output "Ready: port $Port ($ownerInfo)"
        }
        exit 0
    }

    Start-Sleep 2
    $timer += 2
}

Write-Output "ERROR: Not ready after ${MaxWait}s (Port=$Port RunId=$RunId)"
exit 1
