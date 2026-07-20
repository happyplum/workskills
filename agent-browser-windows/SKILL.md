---
name: agent-browser-windows
description: 当在 Windows 上使用 agent-browser（open、snapshot、click、screenshot、wait、浏览器 smoke test、E2E 验证、抓取页面），或排查 agent-browser/Chrome 残留、tool call 卡 running、.agent-browser engine 堆积时使用。
allowed-tools: Bash(agent-browser:*), Bash(powershell:*), Bash(taskkill:*), Bash(where:*), Bash(ls:*), Bash(mkdir:*)
---

# agent-browser 安全使用（Windows）

## 概述

本 skill 处理 `agent-browser` 在 Windows OpenCode 环境下的进程安全：**串行化调用、强制收尾、孤儿进程清理**。`agent-browser` 是 Rust CLI，通过 CDP 驱动 Chrome/Chromium，采用 daemon + Chrome 子树的进程模型。这个模型有三个固有特性需要专门应对：多 subagent 并发冲突、daemon 脱离进程树、sidecar 状态文件生命周期。

**先理解为什么会卡，再看规则。** agent-browser 的进程模型：

```
agent-browser <cmd>           ← 你执行的 CLI，是个短命令：连上 daemon、发指令、退出
        │ (首次 open 时 spawn)
        ▼
agent-browser-win32-x64.exe   ← daemon（长驻），持有 Chrome
        │ (spawn)
        ▼
chrome.exe --remote-debugging-port=0
  --user-data-dir=%TEMP%\agent-browser-chrome-<GUID>   ← 整棵 Chrome 子树
```

**执行模型限制（理解所有防线的前提）**：OpenCode 同一 session 内的 bash 调用是**串行的**。一旦某个 agent-browser 命令卡住（如 `open` 连不上目标，实测 Chrome 导航超时可达 138s+），bash tool 阻塞等待它返回，后续所有 bash 调用全部排队，subagent **自己也被锁死在执行链里**，无法调用清理脚本自救。agent-browser 自身的 action timeout（25s）和 IPC timeout（30s）对 `open` 等待页面加载的场景**不生效**——它等的是 Chrome 导航超时（远超 OpenCode 默认 120s）。唯一能让卡住的命令返回的是 bash tool 的外层 timeout。

**因此：防卡住（让命令在可控时间内一定返回）是第一优先级，比卡住后清理更重要。** 本 skill 的场景脚本（清理/诊断）只能在**非卡住状态**下使用——工作流开始前的预防性清理、或超时恢复后的事后清理，**救不了正在发生的卡住**。

卡住/残留的根因（已在 0.29.1–0.31.2 上实验验证）：

1. **并发是主放大器**：多个 OpenCode subagent 同时调用 `agent-browser` 会互相劫持 session、争抢 profile/Chrome 资源，甚至静默崩溃（官方 issue #326 session 劫持、#1378 session 冲突致 Chrome 静默崩溃、#86 共享实例互相干扰）。社区共识：**用 lock-based 串行化**，而非依赖 idle timeout（#885）。官方的 process-group 修复仅覆盖 daemon 正常退出路径——OpenCode bash tool 超时强杀时绕过它（#1397）。
2. **daemon 脱离 bash 进程树**：daemon 由首次 `open` spawn，之后跨命令复用。当 OpenCode bash tool 超时执行 `taskkill /T /F` 时，daemon 及其 Chrome 子树**不在该命令的进程树内**，杀不掉。实测 daemon 的父进程 PID 已死（`parentAlive=False`）是常态。
3. **`close` 在 sidecar 断裂后失效**：`close` / `close --all` 依赖 sidecar `.pid` 文件定位 daemon。父 shell 被强杀后 session↔daemon 关联可能断裂，`close --all` 实测后仍残留 Chrome。**0.31 的 idle timeout 缓解了"忘了 close"的场景**（见下），但 sidecar 断裂时仍需 cleanup-orphans.ps1 兜底。
4. **`AGENT_BROWSER_IDLE_TIMEOUT_MS`（0.31 已生效，作为安全网）**：0.29.1 时因 select loop bug（#1110）不生效；0.31.2 实测已修复——设为 4000ms 后 daemon 在 ~4s 空闲后自动关闭并清理 Chrome 子树。**但它是计时器兜底，不替代主动 `close`**：锁的释放依赖工作完成即 close（立即让出给排队者），不能等 timeout。
5. **`.engine` 文件永久残留**：每个用过的 session 名都会留下一个 6 字节的 `<session>.engine`（内容恒为 `chrome`），从不自动清理——残留堆积的来源，需定期清理（cleanup-deep.ps1）。
6. **`doctor --fix` 有效但过重**：含网络检查 + launch test，不适合常规收尾。

**一句话结论**：**防卡住超时 wrapper（优先级最高）→ 全局串行化锁 → 主动 `close` → sidecar 验证零残留 → 必要时精确 `taskkill`**。场景脚本是事前预防/事后清理工具，不是卡住自救工具。idle timeout 是额外安全网，不替代主动 close。

**范围**：本 skill 仅覆盖 Windows（PowerShell 7+ / Git Bash）。agent-browser 的命令用法（snapshot、ref、click、fill 等）见 CLI 自带的 `agent-browser skills get core`——本 skill 不重复，只管 Windows 下的进程安全。

## sidecar 文件机制（清理的数据源）

每个活跃 session 在 `~/.agent-browser/`（即 `C:\Users\Administrator\.agent-browser\`）下有 **5 件套**：

| 文件 | 内容 | 用途 |
|------|------|------|
| `<session>.engine` | 恒为 `chrome` | 引擎类型标记。**用过的 session 永久留下，不自动清理** |
| `<session>.pid` | daemon 的 PID | **精确清理的可靠依据** |
| `<session>.port` | CDP 调试端口 | |
| `<session>.stream` | streaming 端口 | |
| `<session>.version` | 如 `0.31.2` | 版本一致性检查 |

判定 session 状态：

- **活跃**：5 件套齐全，且 `.pid` 里的 PID 在进程表中存活且 `ProcessName = agent-browser-win32-x64`。
- **僵尸/孤儿**：有 `.pid` 但该 PID 已死（daemon 被强杀，Chrome 子树可能还活着）。
- **历史残留**：只有 `.engine`，无 `.pid`/`.port`/`.stream`/`.version`（之前正常 close 过，只剩引擎标记）。

清理脚本的精确性完全来自 `.pid` 文件：读它 → 验证 PID 存活且进程名匹配 → `taskkill /T /F`。不靠模糊的进程名扫描。

## 安全边界（清理前必读）

agent-browser 的 Chrome 与用户真实 Chrome **完全可区分**，但清理脚本必须同时校验**两个标记**才能杀：

| 标记 | agent-browser Chrome | 用户真实 Chrome |
|------|---------------------|----------------|
| 可执行路径 | `...\.agent-browser\browsers\chrome-<ver>\chrome.exe` | `...\Google\Chrome\Application\chrome.exe` |
| user-data-dir | `--user-data-dir=...\Temp\agent-browser-chrome-<GUID>` | `...\Google\Chrome\User Data` |

**绝不**按进程名 `chrome.exe` 直接杀——会误杀用户浏览器。必须校验命令行同时含可执行路径标记 **和** `agent-browser-chrome-` user-data-dir 标记。`agent-browser-win32-x64.exe` 进程名唯一，可直接按名处理。

> **PowerShell 正则陷阱**：匹配路径中的反斜杠时，**不要用** `\.agent-browser[\\/]browsers`——实测在 PowerShell `-match` 中 `[\\/]` 字符类对 `\` 匹配失败（返回 False），会让路径校验静默失效。用通配 `.` 代替分隔符：`agent-browser.+browsers`（`.` 匹配 `\` 或 `/`，跨平台且可靠）。本 skill 的脚本均已用此写法。

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **防卡住超时 wrapper（最高优先级）**：每个 agent-browser 命令必须包在可靠的超时里执行。`open`/`wait` 连不上目标或等页面加载时，agent-browser 自身 timeout 不生效，实测可卡 138s+，导致 subagent 执行链阻塞无法自救。必须用 PowerShell `Start-Process` + `WaitForExit(timeout)` + 超时 `taskkill /T /F` 包裹（**不可用** Git Bash `timeout`——它发 SIGTERM 杀不掉 Windows 原生进程）。见 `Invoke-AB` | 命令经 `Invoke-AB`（ab-primitives.ps1）执行；wrapper 含 `WaitForExit` + 超时 kill |
| 2 | **全局串行化锁**：任何 agent-browser 命令前必须先获取全局锁，确保同一时间只有一个 session 在工作。多个 subagent/命令必须排队等待。这是根治并发的关键（官方 #326/#1378/#885） | 工作流以 `Acquire-Lock` 开始、`Release-Lock` 结束 |
| 3 | **必须用命名 session**：每条命令带 `--session <task-name>`，不复用 `default`。session 名要任务相关且唯一（如 `wallet-qa`） | 命令含 `--session <name>`，且 name 非 `default` |
| 4 | **完成后 close 并验证零残留**：工作流末尾执行 `close` 立即释放锁，随后独立验证该 session 的 `.pid` sidecar 已消失、daemon PID 已死。idle timeout（规则 7）是兜底，不替代主动 close——锁的即时让出只靠 close | 命令链末尾有 `close`；验证输出 `closed cleanly` 或列出残留 |
| 5 | **等待优先具体条件**：优先 `wait @ref` / `wait --text "..."` / `wait --url "**/path"`；`networkidle` 仅作兜底；禁止裸 `wait <ms>` | wait 命令非裸 `wait <ms>` |
| 6 | **孤儿清理双重校验 + 计数证明**：清理 Chrome 必须同时校验可执行路径标记 **和** `agent-browser-chrome-` user-data-dir（绝不按进程名单杀）；daemon 用 `.pid` + 进程名双校验；清理脚本输出 before/after 进程数证明有效 | cleanup-orphans.ps1 含两处路径校验 + before/after 计数 |
| 7 | **配置 idle timeout 安全网（0.31+）**：设 `AGENT_BROWSER_IDLE_TIMEOUT_MS`（如 60000），daemon 空闲超时后自动关闭并清理 Chrome。这是「忘了 close / 崩溃残留」的兜底，不是主收尾 | 环境变量在 open 前 export |

## 脚本

脚本位于本 skill 目录的 `scripts/` 下，用绝对路径调用（skill 目录见加载时的 location）。

### 原语模块（dot-source 后使用）

`ab-primitives.ps1` 定义锁原语 + 防卡住 wrapper。工作流开头 dot-source 后即可调用函数：

```powershell
. <skill-dir>/scripts/ab-primitives.ps1
```

提供：`Acquire-Lock` / `Release-Lock`（全局串行化锁，绑定 session 名）/ `Invoke-AB`（防卡住超时 wrapper）/ `Test-SessionDaemonAlive` / `Get-LockHolder`。

### 标准工作流（open-session → 业务步骤 → close-session）

锁管理、open/close、残留验证由配对脚本处理，失败自动清理；中间业务步骤（snapshot/click/wait）逐条用 `Invoke-AB` 执行：

```powershell
. <skill-dir>/scripts/ab-primitives.ps1                                                       # 1. 加载 Invoke-AB
& <skill-dir>/scripts/open-session.ps1  -Session wallet-qa -Url http://127.0.0.1:3000/wallet   # 2. 锁+open（失败自动清理+exit 1）
Invoke-AB -Session wallet-qa -ABArgs @('snapshot','-i','-d','4') -TimeoutSec 15                # 3. 业务步骤（逐条，按需）
& <skill-dir>/scripts/close-session.ps1 -Session wallet-qa                                     # 4. 验证零残留+close+释放锁
```

| 配对脚本 | 职责 |
|---|---|
| `open-session.ps1` | 设 idle timeout → `Acquire-Lock` → `Invoke-AB open`；失败清理残留 daemon + 释放锁 + exit 1 |
| `close-session.ps1` | `Invoke-AB close` → 验证零残留 daemon → `Release-Lock`（finally 兜底，close 失败也执行） |

> 超时衔接：若某条 `Invoke-AB` 返回 `TimedOut = true`，立即跳出，用 `cleanup-orphans.ps1` 清理该 session 残留再释放锁——不要继续后续命令（daemon 状态已不确定）。

### 场景脚本（独立运行）

| 脚本 | 用途 | 何时用 |
|---|---|---|
| `cleanup-orphans.ps1` | 精确孤儿清理（`.pid` sidecar + chrome 双重校验 + before/after 计数） | close 失效或怀疑残留（模板 B） |
| `cleanup-deep.ps1` | 深度清理 `.engine` 残留 + 空 profile 目录（默认 dry-run，`-Apply` 执行） | `.engine` 堆积定期清理（模板 C） |
| `diagnose.ps1` | 卡住诊断（session list + daemon + sidecar + chrome tree + 端口区分） | 超时恢复后/事前排查（模板 D） |

## 反例

| ❌ 错误 | ✅ 正确 |
|---|---|
| 裸 `agent-browser` 调用不经 wrapper（可卡 138s+，执行链阻塞，subagent 无法自救） | 经 `Invoke-AB` wrapper（dot-source `ab-primitives.ps1`） |
| 用 Git Bash `timeout` 包裹（SIGTERM 杀不掉 Windows 原生进程） | 同上，`Invoke-AB` 的 `WaitForExit` + `taskkill /T` |
| 并发调用无锁（session 劫持、Chrome 崩溃、孤儿堆积） | `open-session`/`close-session` 配对（`Acquire`/`Release-Lock`） |
| 裸 open 无 `--session`（用了 default，状态串台） | `--session <task-name>` |
| 忘记 close 或只靠 idle timeout（锁被占满计时，排队者全阻塞） | 完成立即 `close-session.ps1` 释放锁 |
| `taskkill /im chrome.exe`（杀掉用户真实 Chrome） | `cleanup-orphans.ps1`（双重校验：路径标记 + user-data-dir） |
| `taskkill` 不带 `/T`（renderer/gpu 子进程变孤儿） | 带 `/T` 杀进程树 |
| 正则 `[\\/]` 匹配反斜杠（实测对 `\` 失败，校验静默失效） | `agent-browser.+browsers`（`.` 通配分隔符） |
| 浏览器卡住时杀目标端口应用进程（杀错对象） | `diagnose.ps1` 先区分浏览器 daemon PID 与被访问应用 PID |

## 收尾顺序

浏览器操作常涉及访问某个本地端口上的应用。收尾时必须**先 close 浏览器，再由该应用自身的进程管理停止应用**——顺序反了会导致浏览器 `wait` 命令卡在已关闭的端口上，制造新的卡住。本 skill 只负责浏览器侧的 close + 验证 + 锁释放，应用进程的启停不在本 skill 范围。

## 最小触发词

- 主要：`agent-browser`、`open url`、`snapshot`、`click @e`、`screenshot`、`浏览器`、`Chrome 残留`、`tool call 卡 running`、`close --all`、`session list`、`smoke test`、`E2E`、`QA`
- 次要：`daemon`、`sidecar`、`.engine`、`.pid`、`agent-browser-win32-x64`、`agent-browser-chrome-`、`orphan`、`孤儿进程`、`headless chrome`

## 平台事实

| 参数 | 值 |
|------|-----|
| 范围 | Windows（PowerShell 7+ / Git Bash） |
| CLI 版本基准 | agent-browser 0.31.2（行为已验证；0.29.1 的 idle timeout bug 已修） |
| CLI 路径 | `C:\Users\Administrator\.bun\bin\agent-browser.exe` |
| 原生二进制 | `agent-browser-win32-x64.exe`（daemon 进程名） |
| 状态目录 | `C:\Users\Administrator\.agent-browser\`（sidecar 5 件套） |
| Chrome 路径 | `C:\Users\Administrator\.agent-browser\browsers\chrome-<ver>\chrome.exe` |
| Chrome user-data-dir | `%TEMP%\agent-browser-chrome-<GUID>`（每次随机） |
| 默认 action timeout | 25000ms（`AGENT_BROWSER_DEFAULT_TIMEOUT`）——但对 `open`/页面加载不生效 |
| open 卡住实测 | 连不上目标时 Chrome 导航超时可达 138s+；agent-browser 自身 timeout 不覆盖此场景 |
| Git Bash `timeout` 命令 | **无效**——发 SIGTERM 杀不掉 Windows 原生进程；必须用 PowerShell `Start-Process`+`taskkill` |
| 防卡住 wrapper | `Invoke-AB`（ab-primitives.ps1）：`Start-Process` + `WaitForExit(timeout)` + 超时 `taskkill /T /F` |
| `IDLE_TIMEOUT_MS`（0.31+） | 已生效：设值后 daemon 空闲超时自动关闭并清理 Chrome；推荐设 60000 作安全网 |
| `close --all` | 只清 sidecar 关联的 daemon；强杀后的孤儿清不掉 |
| `doctor --fix` | 有效但过重（含网络检查 + launch test） |
| 串行化锁文件 | `%TEMP%\agent-browser-global.lock`（内容 `SESSION=<name>` + 时间戳） |
| 锁原子性 | `[System.IO.File]::Open` + `FileMode.CreateNew`（无 TOCTOU 竞态） |
| 并发官方 issue | #326 session 劫持、#1378 Chrome 静默崩溃、#885 lock-based 方案 |
| Windows kill 进程树 | `taskkill /pid <PID> /T /F`（`/T` 必须有，否则 Chrome 子进程变孤儿） |
