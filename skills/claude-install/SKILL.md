---
name: claude-install
description: >
  在 Windows 或 macOS 上安装、重装或修复 Claude Code(npm 全局版),适用于中国网络环境(npmmirror 镜像)。
  触发场景: "安装 claude"、"重装 Claude Code"、`claude` 命令无法识别、`npm install -g @anthropic-ai/claude-code`
  报 EBUSY、`claude.ps1` 执行策略拦截、claude.exe 变成 500 字节占位脚本需要修复、关闭自动更新;
  macOS:`npm install -g` 报 EACCES、npm 全局目录修复、sudo 安装 Node pkg、settings.json autoUpdates 关闭自动更新。
  Windows 步骤于 2026-08-27 实战验证;macOS 步骤按 2026-08-29 学员实战方案编写,真机首装实录待补。
license: MIT
metadata:
  version: "1.2"
  category: dev-environment
---

# Claude Code 安装与修复(Windows / macOS + npm 全局 + 中国网络)

> Windows 11 + PowerShell 5.1:2026-08-27 实战验证;macOS 13+ (bash 3.2):按 2026-08-29 学员实战方案编写(真机首装实录完成后将补注)。
> 相关 skill:[[dsh-install]];npm 执行策略问题的完整排查见本文第 1 节 Windows 部分(同样适用于 npm 本身)。

## 0. 前置:Node.js ≥ 22(Claude Code v2.1.198 起官方要求)

**Windows**(npmmirror CDN 下载 MSI,静默安装):

```powershell
# 下载(普通权限即可)
Invoke-WebRequest -Uri "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2-x64.msi" -OutFile "$env:TEMP\node-v22.23.2-x64.msi"

# 静默安装(必须以管理员身份打开 PowerShell)
Start-Process msiexec.exe -ArgumentList '/i', "$env:TEMP\node-v22.23.2-x64.msi", '/qn', '/norestart' -Wait
```

**macOS**(npmmirror CDN 下载 pkg,sudo 静默安装,与 Windows msiexec /qn 对等):

```bash
curl -L -o "$HOME/Downloads/node-v22.23.2.pkg" "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2.pkg"
sudo installer -pkg "$HOME/Downloads/node-v22.23.2.pkg" -target /
# 成功判据:"The install was successful.";sudo 密码输入不回显是正常的
```

- 备选源:v24.19.0(Active LTS)、v26.7.0(Current,生产慎用),URL 结构相同,换版本号即可。
- **必须重开终端**再验证 `node -v`(Windows PATH 是终端启动时快照;macOS 新装 pkg 后旧窗口 PATH 也不刷新)。
- 本仓库一键脚本会自动完成本步:Windows 用 `install.ps1` 步骤 2/8,macOS 用 `install.sh` 步骤 2/8。

## 1. 平台拦截解除

**Windows:解除 PowerShell 执行策略拦截**

症状:`npm : 无法加载文件 ...npm.ps1,因为在此系统上禁止运行脚本`

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

- 不需要管理员权限;选 `RemoteSigned` 而非 `Bypass`(保留基本防护)。
- 改完必须重开终端。

**macOS:修复 npm 全局目录(根治 EACCES,学员实战验证)**

症状:`npm install -g` 报 `EACCES: permission denied`(pkg 装的 Node 归 root,/usr/local 下 npm -g 必报)。

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

- 官方不建议 `sudo npm install -g`;改 prefix 是根治方案(预防步骤,不是补救)。
- 仅当 `npm config get prefix` 落在 /usr/local 等 root 目录时才需要;已可写则不动。
- 改完重开终端,验证 `npm config get prefix` 已指向 ~/.npm-global。

## 2. 安装

**Windows**:

```powershell
# 先确认没有 claude 进程在跑,否则报 EBUSY 且会留下半成品安装
Get-Process claude   # 必须无输出;有则关闭所有 Claude Code 窗口

npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
```

**macOS**(EBUSY 检测:`pgrep -f '[c]laude'` 必须无输出;方括号防自匹配):

```bash
pgrep -f '[c]laude'   # 必须无输出;有则关闭所有 Claude Code 窗口
npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
```

## 3. 验证

```bash
claude --version   # 输出版本号即成功
# macOS:若 command not found,先 source ~/.zprofile 或重开终端
```

首次交互使用需要登录或配置 API key —— 见第 6 节的双模型配置模式。

## 4. 故障修复(全部踩坑验证过)

### 4a. `claude` 命令无法识别(shim 丢失,包本体还在)

**Windows**:检查 `C:\Users\<用户>\AppData\Roaming\npm\claude.cmd` 是否存在。不存在则手工创建(内容指向包内 exe):

```cmd
@ECHO off
SETLOCAL
SET dp0=%~dp0
"%dp0%node_modules\@anthropic-ai\claude-code\bin\claude.exe" %*
```

- 刻意**不创建** `claude.ps1`:PowerShell 优先解析 .ps1,若执行策略是 Restricted 会再次触发第 1 节的报错;只留 .cmd 最稳。
- Git Bash 用户额外需要同名无扩展名 shim(调用同一 exe)。

**macOS**:npm 的 bin 是符号链接,损坏时重建即可(指向包内 cli.js):

```bash
ln -sfn ../lib/node_modules/@anthropic-ai/claude-code/cli.js ~/.npm-global/bin/claude
```

### 4b. 二进制占位/损坏

**Windows**:`claude.exe` 是 500 字节占位脚本

症状:`Program 'claude.exe' failed to run: The specified executable is not a valid application for this OS platform`,
且 `...\claude-code\bin\claude.exe` 只有 ~500 字节(内容是 "claude native binary not installed" 的 shell 提示)。

修复 —— 从同包平台二进制复制回来:

```powershell
Copy-Item "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\node_modules\@anthropic-ai\claude-code-win32-x64\claude.exe" `
          "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe" -Force
```

判据:有效的 exe 应 >100MB 且头部为 `MZ`;占位脚本只有几百字节。

**macOS**:平台原生二进制损坏(mac 无同包备份源,不可复制还原,只能重装)

判据:`~/.npm-global/lib/node_modules/@anthropic-ai/claude-code/node_modules/@anthropic-ai/claude-code-darwin-*/claude`
应为 >50MB 且头部为 Mach-O 魔数(feedface/feedfacf/cffaedfe/cafebabe)。

修复:重跑 `npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/` 重新下载平台包。

### 4c. 安装报 EBUSY

根因:运行中的 Claude Code 锁定了自己的二进制。**关闭所有 Claude Code 窗口**(包括正在用的会话)再装。
铁律:绝不 `killall node` / 强杀进程(会误杀 MCP server 等其他 Node 进程)。

### 4d. 残留垃圾

更新中断会留下 `.old.<时间戳>` 备份(几百 MB)。确认 `claude --version` 正常后:

**Windows**:

```powershell
Remove-Item "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe.old.*" -Force
```

**macOS**(残留位于 claude-code-darwin-* 目录下):

```bash
find ~/.npm-global/lib/node_modules/@anthropic-ai/claude-code -maxdepth 4 -name 'claude.old.*' -delete
```

## 5. 关闭自动更新(强烈建议)

双保险:① settings.json 顶层布尔键 `autoUpdates: false`(官方新键)② 环境变量 `DISABLE_AUTOUPDATER=1`(兜底)。

**注意:不要用 `claude config set -g autoUpdates false` —— 该命令有 bug 会把布尔值存成字符串 "false"(真值),不生效;必须直接改 JSON。**

```json
{
  "autoUpdates": false,
  "env": { "DISABLE_AUTOUPDATER": "1" }
}
```

settings.json 路径:Windows `C:\Users\<用户>\.claude\settings.json`,macOS `~/.claude/settings.json`。本仓库一键脚本步骤 7 会自动完成写入(自动合并 + 备份)。

- 若用 `--settings` 自定义配置文件启动,该文件的顶层键与 `env` 块也要加。
- 关闭后手动更新仍可用:`claude update`,或 `npm install -g @anthropic-ai/claude-code@latest --registry=https://registry.npmmirror.com/`(注意 `@latest`,别用 `npm update -g`)。
- 重启会话后用 `claude doctor` 验证显示 `Auto-updates: disabled`。
- 不要用 `DISABLE_UPDATES=1`(连手动更新一起禁)和 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`(捆绑禁用且有 bug)。

## 6. (可选)双模型快捷启动模式

**Windows**:PowerShell profile(`Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`)里加函数:

```powershell
function cc-ds {
    claude --dangerously-skip-permissions --settings "C:\Users\<用户>\.claude-custom.json"
}
```

**macOS**:`~/.zshrc` 加函数(作用相同):

```zsh
cc-ds() {
    claude --dangerously-skip-permissions --settings "$HOME/.claude-custom.json"
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
