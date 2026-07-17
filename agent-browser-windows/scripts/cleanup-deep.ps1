<#
.SYNOPSIS
  agent-browser 深度清理（.engine 残留文件 + 空 profile 临时目录）
.DESCRIPTION
  .engine 文件随每次 session 永久堆积。本脚本清理"只有 .engine 无 .pid"的历史残留，
  以及孤立的 sidecar 残片和空的临时 profile 目录。
  默认 dry-run（只列出）；加 -Apply 执行删除。
  来自 agent-browser-windows skill 模板 C。
.PARAMETER Apply
  执行删除（默认只列出，不删）
.EXAMPLE
  .\cleanup-deep.ps1            # dry-run
  .\cleanup-deep.ps1 -Apply     # 实际删除
#>
param(
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$HOME_DIR = "$env:USERPROFILE\.agent-browser"

# 1. 历史残留 .engine（无对应 .pid = 非活跃 session）
$staleEngines = Get-ChildItem "$HOME_DIR\*.engine" -ErrorAction SilentlyContinue | Where-Object {
    -not (Test-Path ($_.FullName -replace '\.engine$', '.pid'))
}
Write-Output "Stale .engine files (no matching .pid): $($staleEngines.Count)"
$staleEngines | ForEach-Object { Write-Output "  $($_.Name)" }

# 2. 孤立 sidecar 残片（有 .port/.stream/.version 但无 .pid = 僵尸遗留）
$orphanSidecars = Get-ChildItem "$HOME_DIR\*.port","$HOME_DIR\*.stream","$HOME_DIR\*.version" -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-Path ($_.FullName -replace '\.(port|stream|version)$', '.pid')) }
if ($orphanSidecars) { Write-Output "Orphan sidecar fragments: $($orphanSidecars.Count)" }

# 3. 空的临时 profile 目录
$staleTempDirs = Get-ChildItem $env:TEMP -Directory -Filter 'agent-browser-chrome-*' -ErrorAction SilentlyContinue |
    Where-Object { -not (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue) }
Write-Output "Empty temp profile dirs: $(@($staleTempDirs).Count)"

if ($Apply) {
    $staleEngines   | Remove-Item -Force -ErrorAction SilentlyContinue
    $orphanSidecars | Remove-Item -Force -ErrorAction SilentlyContinue
    $staleTempDirs  | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Applied: stale files removed."
} else {
    Write-Output "Dry run complete. Re-run with -Apply to actually delete."
}
