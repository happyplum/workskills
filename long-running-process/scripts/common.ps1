<#
.SYNOPSIS
  long-running-process 共享原语：RunId state、进程树归属
#>
Set-StrictMode -Version Latest

function Get-LrpStateRoot {
    $root = Join-Path $env:TEMP 'opencode-long-running'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Get-LrpStatePath {
    param([Parameter(Mandatory)][string]$RunId)
    if ($RunId -notmatch '^[A-Za-z0-9._-]+$') {
        throw "Invalid RunId: $RunId"
    }
    return (Join-Path (Get-LrpStateRoot) "$RunId.json")
}

function Read-LrpState {
    param([Parameter(Mandatory)][string]$RunId)
    $path = Get-LrpStatePath -RunId $RunId
    if (-not (Test-Path -LiteralPath $path)) {
        throw "State not found for RunId=$RunId path=$path"
    }
    return (Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json)
}

function Write-LrpState {
    param([Parameter(Mandatory)]$State)
    $path = Get-LrpStatePath -RunId $State.RunId
    $json = $State | ConvertTo-Json -Depth 6
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $json, $utf8)
    return $path
}

function Test-LrpProcessAlive {
    param([Parameter(Mandatory)][int]$ProcessId)
    return [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Get-LrpAncestorChain {
    param([Parameter(Mandatory)][int]$ProcessId)
    # List 作为单一对象返回，避免 PS 数组解包
    $chain = [System.Collections.Generic.List[int]]::new()
    $current = $ProcessId
    $guard = 0
    while ($current -gt 0 -and $guard -lt 64) {
        $chain.Add($current) | Out-Null
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$current" -ErrorAction SilentlyContinue
        if (-not $proc) { break }
        $parent = [int]$proc.ParentProcessId
        if ($parent -le 0 -or $parent -eq $current) { break }
        $current = $parent
        $guard++
    }
    Write-Output -NoEnumerate -InputObject $chain
}

function Test-LrpPidInControlTree {
    param(
        [Parameter(Mandatory)][int]$CandidatePid,
        [Parameter(Mandatory)][int]$ControlPid,
        [int]$AppPid = 0
    )
    if ($CandidatePid -eq $ControlPid) { return $true }
    if ($AppPid -gt 0 -and $CandidatePid -eq $AppPid) { return $true }
    $chain = Get-LrpAncestorChain -ProcessId $CandidatePid
    if ($chain.Contains($ControlPid)) { return $true }
    if ($AppPid -gt 0 -and $chain.Contains($AppPid)) { return $true }
    return $false
}

function Get-LrpListenersOnPort {
    param([Parameter(Mandatory)][int]$Port)
    $owners = [System.Collections.Generic.List[int]]::new()
    $rows = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($null -ne $rows) {
        foreach ($row in @($rows)) {
            $pidVal = [int]$row.OwningProcess
            if (-not $owners.Contains($pidVal)) {
                $owners.Add($pidVal) | Out-Null
            }
        }
    }
    Write-Output -NoEnumerate -InputObject $owners
}

function Test-LrpPortOwnedByRun {
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][int]$ControlPid,
        [int]$AppPid = 0
    )
    $owners = Get-LrpListenersOnPort -Port $Port
    if ($owners.Count -eq 0) { return $false }
    foreach ($owner in $owners) {
        if (-not (Test-LrpPidInControlTree -CandidatePid ([int]$owner) -ControlPid $ControlPid -AppPid $AppPid)) {
            return $false
        }
    }
    return $true
}
