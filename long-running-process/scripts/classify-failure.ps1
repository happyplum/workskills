<#
.SYNOPSIS
  启动失败分类（读 stderr 日志匹配已知错误模式）
.DESCRIPTION
  当 start-background 启动成功但 wait-ready 超时时，用本脚本读日志分类失败原因。
  来自 long-running-process skill 模板 5。
.PARAMETER LogPath
  stderr 日志路径（start-background 输出的 *-stderr-*.log）
.EXAMPLE
  .\classify-failure.ps1 -LogPath "$env:TEMP\dev-stderr-12345.log"
#>
param(
    [Parameter(Mandatory)][string]$LogPath
)
Set-StrictMode -Version Latest

if (-not (Test-Path $LogPath)) { Write-Output "ERROR: Log file not found: $LogPath"; exit 1 }

$tail = Get-Content $LogPath -Tail 50 -ErrorAction SilentlyContinue
$errors = @(
    @{ Pattern = "EADDRINUSE|address already in use"; Reason = "Port conflict — another process using this port" },
    @{ Pattern = "ENOENT|Cannot find module|Error: Cannot resolve"; Reason = "Missing dependency — run pnpm install" },
    @{ Pattern = "SyntaxError|Unexpected token|Expected"; Reason = "Syntax error in source code" },
    @{ Pattern = "ENOMEM|heap out of memory|FATAL ERROR"; Reason = "Out of memory — close other processes or increase Node heap" },
    @{ Pattern = "EACCES|permission denied"; Reason = "Permission error — check file/directory permissions" }
)

foreach ($e in $errors) {
    if ($tail | Select-String -Pattern $e.Pattern -Quiet) {
        Write-Output "ERROR: $($e.Reason)`nLast 10 lines:`n$(($tail | Select-Object -Last 10) -join "`n")"
        exit 1
    }
}

Write-Output "WARNING: No known error pattern matched. Raw last 20 lines:`n$(($tail | Select-Object -Last 20) -join "`n")"
exit 1
