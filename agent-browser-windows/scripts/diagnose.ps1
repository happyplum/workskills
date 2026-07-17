<#
.SYNOPSIS
  agent-browser 卡住诊断（超时恢复后 / 事后排查）
.DESCRIPTION
  定位浏览器进程再决定清理。注意：真正卡住期间无法调用本脚本（执行链阻塞）——
  用于超时恢复后的事后排查，不是实时自救。
  绝不盲目杀掉目标端口上的应用进程——浏览器残留和应用进程无关。
  来自 agent-browser-windows skill 模板 D。
.EXAMPLE
  .\diagnose.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Output "=== Active agent-browser sessions ==="
agent-browser session list

Write-Output "`n=== Live daemons ==="
Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue |
    Select-Object Id, StartTime | Format-Table -AutoSize

Write-Output "`n=== Sidecar .pid files (live?) ==="
Get-ChildItem "$env:USERPROFILE\.agent-browser\*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    $dpid = (Get-Content $_.FullName -Raw).Trim()
    $alive = if (Get-Process -Id $dpid -ErrorAction SilentlyContinue) { 'LIVE' } else { 'DEAD' }
    Write-Output "  $($_.BaseName): pid=$dpid => $alive"
}

Write-Output "`n=== agent-browser Chrome trees (roots only) ==="
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' -and $_.CommandLine -notmatch '--type=' } |
    Select-Object ProcessId, @{N='ParentProcessId';E={$_.ParentProcessId}} |
    Format-Table -AutoSize

Write-Output "`n=== Distinguish from unrelated port owners (e.g. :3000 target app) ==="
$conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    Write-Output "Port 3000 owner: PID=$($owner.ProcessId) Name=$($owner.Name)"
    Write-Output "  -> This is the TARGET APP the browser is visiting. Do NOT kill it for a browser hang."
}

Write-Output "`n=== Diagnosis complete ==="
Write-Output "若发现浏览器残留 -> cleanup-orphans.ps1。若端口上的应用进程才是问题源，属应用进程管理，不在本 skill 范围。"
