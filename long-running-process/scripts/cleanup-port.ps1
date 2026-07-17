<#
.SYNOPSIS
  清理占用指定端口的进程（精确匹配，防误杀）
.DESCRIPTION
  按端口定位占用进程，验证其命令行包含 RequireMatch 后 taskkill /T /F。
  RequireMatch 必须是绝对项目路径、唯一 session/port 标记或完整命令片段——
  不要用 node/pnpm/chrome 这类裸可执行名（太宽泛会误杀）。
  来自 long-running-process skill 模板 4。
.PARAMETER Port
  端口号
.PARAMETER RequireMatch
  命令行必须包含的子串（精确归属验证）
.EXAMPLE
  .\cleanup-port.ps1 -Port 3000 -RequireMatch "my-project\node_modules"
#>
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$RequireMatch
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($conn) {
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    if (-not $owner) {
        Write-Output "ERROR: Owning process $($conn.OwningProcess) not found. Refusing cleanup."
        exit 1
    }

    $ownerInfo = $owner | Select-Object ProcessId, Name, CommandLine | Format-List | Out-String
    Write-Output "Candidate owner:`n$ownerInfo"

    $commandLine = $owner.CommandLine
    if (($null -eq $commandLine) -or ($commandLine.IndexOf($RequireMatch, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
        Write-Output "ERROR: PID $($conn.OwningProcess) does not match RequireMatch '$RequireMatch'. Refusing cleanup."
        exit 1
    }

    taskkill /pid $conn.OwningProcess /T /F 2>$null
    Write-Output "Killed process tree for PID $($conn.OwningProcess)"
} else {
    Write-Output "Port $Port is free"
}
