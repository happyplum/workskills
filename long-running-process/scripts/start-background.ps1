<#
.SYNOPSIS
  长运行后台进程安全启动（Windows / PowerShell 7+）
.DESCRIPTION
  用 WMI Win32_Process.Create 隔离 OpenCode pipe，启动 dev server / 构建命令等长运行后台进程。
  返回 PID + 日志路径。含端口占用验证 + 2s liveness check。
  来自 long-running-process skill 模板 1。
.PARAMETER Pm
  包管理器或可执行文件，如 pnpm.cmd / npm.cmd / flutter / cargo
.PARAMETER CommandArgs
  命令参数字符串，如 "dev" / "start" / "run"
.PARAMETER Port
  预期监听端口（启动前占用检查）
.PARAMETER Dir
  工作目录
.PARAMETER LogPrefix
  日志文件前缀
.EXAMPLE
  .\start-background.ps1 -Pm pnpm.cmd -CommandArgs "dev" -Port 3000 -Dir . -LogPrefix dev
#>
param(
    [Parameter(Mandatory)][string]$Pm,
    [Parameter(Mandatory)][string]$CommandArgs,
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$LogPrefix
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 端口占用 — 必须验证归属（规则 5）
$portConn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($portConn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($portConn.OwningProcess)" |
        Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
    Write-Output "ERROR: Port $Port already in use.`n$owner"
    exit 1
}

# 解析可执行文件（缺失时输出可控错误）
try {
    $exe = (Get-Command $Pm -ErrorAction Stop).Source
} catch {
    Write-Output "ERROR: $Pm not found; install or fix PATH"
    exit 1
}

$stdoutLog = "$env:TEMP\${LogPrefix}-stdout-$PID.log"
$stderrLog = "$env:TEMP\${LogPrefix}-stderr-$PID.log"

# WMI Win32_Process.Create 隔离启动：不用 Start-Process（pipe 句柄继承会导致 Node close 事件不触发）
$launcher = "$env:TEMP\${LogPrefix}-launch-$PID.cmd"
@"
@echo off
cd /d "$Dir" || exit /b 1
call "$exe" $CommandArgs 1>"$stdoutLog" 2>"$stderrLog" <NUL
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII

$startup = ([wmiclass]'Win32_ProcessStartup').CreateInstance()
$startup.ShowWindow = 0
$result = ([wmiclass]'Win32_Process').Create("$env:ComSpec /d /c `"$launcher`"", $Dir, $startup)
if ($result.ReturnValue -ne 0) {
    Write-Output "ERROR: Win32_Process.Create failed with code $($result.ReturnValue)"
    exit 1
}

# 2s liveness check — 进程可能立即崩溃
Start-Sleep 2
if (-not (Get-Process -Id $result.ProcessId -ErrorAction SilentlyContinue)) {
    $errLog = Get-Content $stderrLog -Tail 10 -ErrorAction SilentlyContinue
    Write-Output "ERROR: Process $($result.ProcessId) died immediately.`nLast stderr:`n$errLog"
    exit 1
}

Write-Output "Started PID: $($result.ProcessId)"
Write-Output "Logs: $stdoutLog / $stderrLog"
