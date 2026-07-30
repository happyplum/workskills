<#
.SYNOPSIS
  WMI 隔离后的 supervisor：ArgumentList 启动应用并回写 AppPid
.PARAMETER ConfigPath
  UTF-8 JSON：Exe, Args[], WorkDir, StdoutLog, StderrLog, StatePath
#>
param(
    [Parameter(Mandatory)][string]$ConfigPath
)
# 尽早写 boot 日志（不依赖 config 解析）
$bootLog = "$ConfigPath.boot.log"
function Write-Boot([string]$Msg) {
    $line = '{0:o} {1}' -f [DateTime]::UtcNow, $Msg
    [System.IO.File]::AppendAllText($bootLog, $line + [Environment]::NewLine)
}

try {
    Write-Boot "start ConfigPath=$ConfigPath"
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config not found: $ConfigPath"
    }

    $raw = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
    $cfg = $raw | ConvertFrom-Json
    $argsList = @()
    if ($null -ne $cfg.Args) { $argsList = @($cfg.Args | ForEach-Object { [string]$_ }) }

    $exe = [string]$cfg.Exe
    $workDir = [string]$cfg.WorkDir
    $stdoutLog = [string]$cfg.StdoutLog
    $stderrLog = [string]$cfg.StderrLog
    $statePath = [string]$cfg.StatePath

    Write-Boot "exe=$exe workDir=$workDir args=$($argsList.Count)"

    if (-not (Test-Path -LiteralPath $workDir)) {
        throw "WorkDir not found: $workDir"
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Exe not found: $exe"
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exe
    $psi.WorkingDirectory = $workDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $false
    $psi.CreateNoWindow = $true
    foreach ($a in $argsList) {
        [void]$psi.ArgumentList.Add($a)
    }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $started = $proc.Start()
    if (-not $started) { throw "Process.Start returned false for $exe" }
    Write-Boot "AppPid=$($proc.Id)"

    # 回写 AppPid（PSCustomObject 可能不可追加属性，重建 hashtable）
    $stateRaw = [System.IO.File]::ReadAllText($statePath, [System.Text.UTF8Encoding]::new($false))
    $prev = $stateRaw | ConvertFrom-Json
    $stateOut = [ordered]@{}
    foreach ($p in $prev.PSObject.Properties) {
        $stateOut[$p.Name] = $p.Value
    }
    $stateOut['AppPid'] = $proc.Id
    $stateOut['AppStartedUtc'] = [DateTime]::UtcNow.ToString('o')
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($statePath, ($stateOut | ConvertTo-Json -Depth 8), $utf8)
    Write-Boot "state updated"

    $stdoutFs = [System.IO.File]::Open($stdoutLog, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    $stderrFs = [System.IO.File]::Open($stderrLog, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try {
        $outCopy = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutFs)
        $errCopy = $proc.StandardError.BaseStream.CopyToAsync($stderrFs)
        $proc.WaitForExit()
        try { $outCopy.Wait(5000) | Out-Null } catch { }
        try { $errCopy.Wait(5000) | Out-Null } catch { }
        Write-Boot "exit=$($proc.ExitCode)"
        exit [int]$proc.ExitCode
    } finally {
        $stdoutFs.Dispose()
        $stderrFs.Dispose()
        $proc.Dispose()
    }
} catch {
    Write-Boot "ERROR: $($_.Exception.Message)"
    Write-Boot ($_ | Out-String)
    exit 1
}
