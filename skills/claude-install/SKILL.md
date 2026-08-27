---
name: claude-install
description: >
  在 Windows 上安装、重装或修复 Claude Code(npm 全局版),适用于中国网络环境(npmmirror 镜像)。
  触发场景: "安装 claude"、"重装 Claude Code"、`claude` 命令无法识别、`npm install -g @anthropic-ai/claude-code`
  报 EBUSY、`claude.ps1` 执行策略拦截、claude.exe 变成 500 字节占位脚本需要修复、关闭自动更新。
  全部步骤于 2026-08-27 实战验证有效。
license: MIT
metadata:
  version: "1.0"
  category: dev-environment
---

# Claude Code 安装与修复(Windows + npm 全局 + 中国网络)

> 2026-08-27 实战验证。适用:Windows 11 + PowerShell 5.1,npm 走 npmmirror 镜像。
> 相关 skill:[[dsh-install]];npm 执行策略问题的完整排查见本文第 1 节(同样适用于 npm 本身)。

## 0. 前置:Node.js ≥ 20

没有 Node 或版本过低时,从 npmmirror CDN 下载 MSI(已验证的直链,22 线最新 LTS):

```powershell
# 下载(普通权限即可)
Invoke-WebRequest -Uri "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2-x64.msi" -OutFile "$env:TEMP\node-v22.23.2-x64.msi"

# 静默安装(必须以管理员身份打开 PowerShell)
Start-Process msiexec.exe -ArgumentList '/i', "$env:TEMP\node-v22.23.2-x64.msi", '/qn', '/norestart' -Wait
```

- 备选源:v24.19.0(Active LTS)、v26.7.0(Current,生产慎用),URL 结构相同,换版本号即可。
- **必须重开终端**再验证 `node -v` —— Windows PATH 是终端启动时快照,旧窗口不生效。

## 1. 解除 PowerShell 执行策略拦截

症状:`npm : 无法加载文件 ...npm.ps1,因为在此系统上禁止运行脚本`

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

- 不需要管理员权限;选 `RemoteSigned` 而非 `Bypass`(保留基本防护)。
- 改完必须重开终端。

## 2. 安装

```powershell
# 先确认没有 claude 进程在跑,否则报 EBUSY 且会留下半成品安装
Get-Process claude   # 必须无输出;有则关闭所有 Claude Code 窗口

npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
```

## 3. 验证

```powershell
claude --version   # 输出版本号即成功
```

首次交互使用需要登录或配置 API key —— 见第 6 节的双模型配置模式。

## 4. 故障修复(全部踩坑验证过)

### 4a. `claude` 命令无法识别(shim 丢失,包本体还在)

检查 `C:\Users\<用户>\AppData\Roaming\npm\claude.cmd` 是否存在。不存在则手工创建(内容指向包内 exe):

```cmd
@ECHO off
SETLOCAL
SET dp0=%~dp0
"%dp0%node_modules\@anthropic-ai\claude-code\bin\claude.exe" %*
```

- 刻意**不创建** `claude.ps1`:PowerShell 优先解析 .ps1,若执行策略是 Restricted 会再次触发第 1 节的报错;只留 .cmd 最稳。
- Git Bash 用户额外需要同名无扩展名 shim(调用同一 exe)。

### 4b. `claude.exe` 是 500 字节占位脚本

症状:`Program 'claude.exe' failed to run: The specified executable is not a valid application for this OS platform`,
且 `...\claude-code\bin\claude.exe` 只有 ~500 字节(内容是 "claude native binary not installed" 的 shell 提示)。

修复 —— 从同包平台二进制复制回来:

```powershell
Copy-Item "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\node_modules\@anthropic-ai\claude-code-win32-x64\claude.exe" `
          "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe" -Force
```

判据:有效的 exe 应 >100MB 且头部为 `MZ`;占位脚本只有几百字节。

### 4c. 安装报 EBUSY

根因:运行中的 Claude Code 锁定了自己的 exe。**关闭所有 Claude Code 窗口**(包括正在用的会话)再装。

### 4d. 残留垃圾

更新中断会在 `bin\` 留下 `claude.exe.old.<时间戳>` 备份(几百 MB)。确认 `claude --version` 正常后:

```powershell
Remove-Item "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe.old.*" -Force
```

## 5. 关闭自动更新(强烈建议)

唯一有效开关:`DISABLE_AUTOUPDATER=1`(`autoUpdates` 键已废弃,勿用)。

写入两层:

```powershell
# 层 1:用户级环境变量(兜底,所有 shell 生效)
[Environment]::SetEnvironmentVariable("DISABLE_AUTOUPDATER", "1", "User")
```

```json
// 层 2:C:\Users\<用户>\.claude\settings.json 的 env 块
{ "env": { "DISABLE_AUTOUPDATER": "1" } }
```

- 若用 `--settings` 自定义配置文件启动,该文件的 `env` 块也要加。
- 关闭后手动更新仍可用:`claude update`,或 `npm install -g @anthropic-ai/claude-code@latest --registry=https://registry.npmmirror.com/`(注意 `@latest`,别用 `npm update -g`)。
- 重启会话后用 `claude doctor` 验证显示 `Auto-updates: disabled`。
- 不要用 `DISABLE_UPDATES=1`(连手动更新一起禁)和 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`(捆绑禁用且有 bug)。

## 6. (可选)双模型快捷启动模式

PowerShell profile(`Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`)里加函数:

```powershell
function cc-ds {
    claude --dangerously-skip-permissions --settings "C:\Users\<用户>\.claude-custom.json"
}
```

> 安全提示:`--dangerously-skip-permissions` 会跳过权限确认,仅建议单机本地自用。

对应的 `--settings` 文件放模型/env 配置(参考本机 `.claude-custom.json` 实测结构):

```json
{
  "model": "deepseek-v4-pro",
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-xxx",
    "ANTHROPIC_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "deepseek-v4-pro",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-pro",
    "CLAUDE_CODE_EFFORT_LEVEL": "max",
    "DISABLE_AUTOUPDATER": "1"
  }
}
```
