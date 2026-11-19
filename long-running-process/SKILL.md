---
name: long-running-process
description: 当确认运行环境为 Windows + PowerShell，且需要启动或管理后台长运行进程（如 dev server、watcher、长构建）、等待端口或健康检查就绪、按 RunId 停止残留进程，或执行可能超时的构建命令时使用。
---

# Windows 长运行进程安全管理

## 概述

在 Windows 上通过自动化终端（如 Agent shell / OpenCode 等）执行 PowerShell 命令时，单次命令通常带有超时上限，超时后会直接 `taskkill /T /F` 杀掉整个命令树。直接用普通方式启动后台进程会踩三个典型坑：

- **无上限轮询**：`while` 循环不设超时上限，命令永远不返回，最终被外部超时强杀。
- **管道继承卡死**：在终端内直接用 `Start-Process` 启动后台服务，子进程可能继承标准输入输出管道，导致上层进程一直等待关闭事件而卡住。
- **后台进程脱管成孤儿**：通过 WMI 脱离当前进程树启动的应用，在就绪等待失败或终端超时后**仍可能继续存活**；如果不记录 `RunId` 归属关系，后续极易残留占端口或误杀别的服务。

本 skill 通过 `<skill-dir>/scripts/` 下的 PowerShell 脚本解决上述问题：经 WMI 启动仅含 ASCII 路径的引导器，再由 PowerShell 监控进程通过 `ProcessStartInfo.ArgumentList` 启动目标应用（用户参数和中文/Unicode 工作目录全部写在 UTF-8 JSON 配置中），并在 `%TEMP%\opencode-long-running\<RunId>.json` 中维护完整的 `RunId`、`ControlPid`、`AppPid` 与日志路径。

> **适用范围**：仅限 Windows（PowerShell 7+）下的**应用进程**（开发服务器、构建任务、文件监听）。不适用于浏览器自动化进程，也不适用于 Unix/macOS。

## 强制规则

| # | 规则 | 验证要点 |
|---|---|---|
| 1 | **禁止无上限等待**：所有轮询必须显式设置 `MaxWait`，且满足 `MaxWait + 清理余量 < 本次调用的外部超时` | 循环有明确上限；外部 `timeout` 显式设置且大于内部等待 |
| 2 | **禁止在终端内直接 `Start-Process` 启动后台服务**：统一调用 `start-background.ps1` 启动 | 启动后输出包含 `RunId`、`ControlPid`、`AppPid` 与状态文件路径 |
| 3 | **启动与就绪检查分成两次独立调用**：就绪检查有超时上限、失败返回 `exit 1`，且传入 `-RunId` 时必须校验监听端口属于本次启动的进程树 | 使用 `wait-ready.ps1 -RunId`；外来进程占端口直接判失败 |
| 4 | **可能耗时较长的命令必须显式设置外部 `timeout`（ms）**：不要凭旧记忆套用固定超时值，以当前终端工具支持的最大超时为准 | 调用显式传 `timeout`，与 `MaxWait` 配套可算 |
| 5 | **端口已被占用不得直接当作就绪**：启动前端口已占用应失败；就绪检查需校验归属；按端口清理发现多个监听进程时拒绝盲杀 | 非预期占用均明确报错退出 |
| 6 | **按 `RunId` 停止进程**：无端口的 watcher 或构建任务也必须能通过 `stop-background.ps1 -RunId` 清理，不要只把裸 PID 当凭据 | 状态文件存在，停止后对应进程树完全消失 |

## 超时预算原则

- **核心不等式**：`内部 MaxWait + 清理余量 < 本次调用显式设置的外部超时`
- 冷启动按项目实际情况给足 `MaxWait`，不要硬套过时的「默认 120 秒」表。
- 经验参考量级（非硬性约定）：Vite 热启动约数秒～30s；Next.js 冷启动可达 60s；Cargo 冷编译可达数分钟——确保外部超时覆盖得住即可。

## 脚本使用说明

脚本位于 `<skill-dir>/scripts/`（实际路径见加载本 skill 时的目录位置）。

### 标准生命周期：启动 → 等待就绪 → 停止

```powershell
# 1. 启动（独立一次命令调用；CommandArgs 传数组）
& "<skill-dir>/scripts/start-background.ps1" -Pm pnpm.cmd -CommandArgs @('dev') -Port 3000 -Dir 'C:\proj' -LogPrefix dev

# 2. 等待就绪（另起一次独立调用；传入上一步返回的 RunId）
& "<skill-dir>/scripts/wait-ready.ps1" -RunId <RunId> -MaxWait 60
# 如需同时校验健康检查接口：
# & "<skill-dir>/scripts/wait-ready.ps1" -RunId <RunId> -MaxWait 60 -HealthUrl http://localhost:3000/

# 3. 停止进程树
& "<skill-dir>/scripts/stop-background.ps1" -RunId <RunId>
```

无监听端口的 watcher 或长构建任务：省略 `-Port`，同样用 `RunId` 管理启停。

### 脚本清单

| 脚本 | 用途 | 关键参数 |
|---|---|---|
| `start-background.ps1` | 通过 WMI 与监控进程安全启动后台任务，并写入 `RunId` 状态文件 | `-Pm` `-CommandArgs` `[-Port]` `-Dir` `-LogPrefix` |
| `wait-ready.ps1` | 有上限等待端口或健康检查就绪；传 `-RunId` 时校验端口进程归属 | `-MaxWait` `[-RunId]` `[-Port]` `[-HealthUrl]` |
| `stop-background.ps1` | 按 `RunId` 终止整个进程树并验证已退出 | `-RunId` `[-RequirePortFree]` |
| `capture-timed.ps1` | 限时运行并捕获日志后终止进程树（适合冒烟验证） | `-Exe` `-CommandArgs` `-TimeoutSec` `-LogPrefix` `[-Dir]` |
| `cleanup-port.ps1` | 没有 `RunId` 时按端口 + 命令行特征清理；发现多个监听进程时拒绝执行 | `-Port` `-RequireMatch` |
| `classify-failure.ps1` | 读取错误日志做初步失败原因分类 | `-LogPath` |
| `common.ps1` / `supervisor-run.ps1` | 内部基础模块，供上述脚本调用，不直接作为业务入口 | — |

> 使用 `cleanup-port.ps1` 时，`-RequireMatch` 必须是项目绝对路径或唯一标识，禁止只写 `node`、`pnpm` 这类宽泛进程名。有 `RunId` 时始终优先用 `stop-background.ps1 -RunId`。

状态文件目录：`%TEMP%\opencode-long-running\<RunId>.json`（记录 `ControlPid`、`AppPid`、`WorkDir`、`Port` 与日志路径）。

## 反例

| 看似合理但错误 | 正确做法 |
|---|---|
| 写无上限的 `while { Start-Sleep 1 }` 等服务启动 | 用 `wait-ready.ps1 -MaxWait N` 做有界等待 |
| 看到端口处于 Listen 就直接 `exit 0` | 用 `-RunId` 校验端口归属，防止误把旧服务或别的服务当成就绪 |
| 在终端里直接 `Start-Process` 挂 dev server | 使用 `start-background.ps1` 脱离管道继承 |
| 在 `.cmd` 文件里拼接复杂参数或中文路径 | 通过 UTF-8 JSON 配置与 `ArgumentList` 传递参数和路径 |
| 只把 `"PID: 1234"` 记在文本里，跨会话直接强杀 | 用 `RunId` 状态文件配合 `stop-background.ps1` 校验并清理 |
| 等待就绪超时后不清理就直接再次启动 | 先确认旧进程已停止或可安全复用，再决定是否重启 |
| 按固定「120 秒」经验值盲估超时预算 | 每次显式传入外部 `timeout`，并确保大于内部 `MaxWait` |

## 环境说明

| 项 | 说明 |
|---|---|
| 支持环境 | Windows，PowerShell 7+ |
| 外部超时上限 | 以当前终端工具 schema 声明为准，不在文档中写死易变数值 |
| 超时终止机制 | 外部超时会以 `taskkill /pid … /T /F` 杀掉当前命令树 |
| 脱离运行特性 | WMI 启动的子进程树不会因为 `wait-ready.ps1` 返回 `exit 1` 而自动退出，需显式停止 |
| 编码支持 | 工作目录与参数经 UTF-8 JSON 与 `ArgumentList` 传递，支持中文及 Unicode 路径 |
