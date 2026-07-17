<#
.SYNOPSIS
  就绪检查（端口 / health endpoint，有界超时）
.DESCRIPTION
  独立 bash 调用，有界轮询端口或 health endpoint。就绪 exit 0，超时 exit 1。
  必须与 start-background 分两个独立 bash 调用（规则 3）。
  来自 long-running-process skill 模板 2。
.PARAMETER Port
  待检查端口
.PARAMETER MaxWait
  最大等待秒数（查框架预算表选择，须 < bash tool timeout）
.PARAMETER HealthUrl
  可选 health endpoint URL；提供时优先用它而非端口检查
.EXAMPLE
  .\wait-ready.ps1 -Port 3000 -MaxWait 60
  .\wait-ready.ps1 -Port 8080 -MaxWait 120 -HealthUrl http://localhost:8080/health
#>
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][int]$MaxWait,
    [string]$HealthUrl
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$timer = 0
while ($timer -lt $MaxWait) {
    if ($HealthUrl) {
        try {
            $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            Write-Output "Health check passed (status $($r.StatusCode))"; exit 0
        } catch { }
    } else {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($conn) { Write-Output "Port $Port ready (PID $($conn.OwningProcess))"; exit 0 }
    }
    Start-Sleep 2; $timer += 2
}
Write-Output "ERROR: Port $Port not ready after ${MaxWait}s"
exit 1
