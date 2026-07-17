<#
.SYNOPSIS
  agent-browser 精确孤儿清理（基于 sidecar .pid，双重安全校验）
.DESCRIPTION
  当 close 失效或怀疑有残留时用。读 .pid sidecar 精确定位 daemon，
  双重校验 chrome（可执行路径标记 + user-data-dir 标记）。
  输出 before/after 计数证明有效（规则 8）。
  来自 agent-browser-windows skill 模板 B。
.EXAMPLE
  .\cleanup-orphans.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$HOME_DIR = "$env:USERPROFILE\.agent-browser"

# === before 计数 ===
$abBefore = @(Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue).Count
$chromeBefore = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' }).Count
Write-Output "BEFORE: agent-browser daemons=$abBefore  agent-browser chrome=$chromeBefore"

# === 第一类：读 .pid sidecar，清理僵尸/孤儿 daemon ===
$pidFiles = Get-ChildItem "$HOME_DIR\*.pid" -ErrorAction SilentlyContinue
foreach ($pf in $pidFiles) {
    $daemonPid = (Get-Content $pf.FullName -Raw).Trim()
    $proc = Get-Process -Id $daemonPid -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -eq 'agent-browser-win32-x64') {
        Write-Output "Killing daemon PID $daemonPid (session $($pf.BaseName)) — still alive"
        taskkill /pid $daemonPid /T /F 2>$null
    } elseif ($proc) {
        Write-Output "SKIP: PID $daemonPid is alive but NOT agent-browser (is $($proc.ProcessName)) — safety stop"
    } else {
        Write-Output "Stale sidecar: $($pf.Name) -> PID $daemonPid already dead"
    }
}

# === 第二类：扫描残留的 agent-browser Chrome（双重校验）===
# 校验 1: 可执行路径标记（用 .+ 通配分隔符，避免 PowerShell 反斜杠字符类陷阱）
# 校验 2: user-data-dir 含 agent-browser-chrome-
$orphanChrome = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object {
    $_.CommandLine -and
    ($_.CommandLine -match 'agent-browser.+browsers') -and
    ($_.CommandLine -match 'agent-browser-chrome-')
}
foreach ($c in $orphanChrome) {
    # 只杀进程树的根（主进程，无 --type= 子参数）
    if ($c.CommandLine -notmatch '--type=') {
        Write-Output "Killing chrome tree root PID $($c.ProcessId)"
        taskkill /pid $c.ProcessId /T /F 2>$null
    }
}

Start-Sleep -Milliseconds 800

# === after 计数（规则 8）===
$abAfter = @(Get-Process agent-browser-win32-x64 -ErrorAction SilentlyContinue).Count
$chromeAfter = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -match 'agent-browser.+browsers' }).Count
Write-Output "AFTER:  agent-browser daemons=$abAfter  agent-browser chrome=$chromeAfter"
if ($abAfter -eq 0 -and $chromeAfter -eq 0) {
    Write-Output "CLEAN: zero residue"
} else {
    Write-Output "WARNING: $abAfter daemon(s) / $chromeAfter chrome(s) remain — run 'agent-browser doctor --fix' or inspect manually"
}
