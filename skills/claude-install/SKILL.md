---
name: claude-install
description: >
  在 Windows 或 macOS 上安装、重装或修复 Claude Code(npm 全局版),适用于中国网络环境(npmmirror 镜像)。
  触发场景: "安装 claude"、"重装 Claude Code"、`claude` 命令无法识别、`npm install -g @anthropic-ai/claude-code`
  报 EBUSY/ENOTEMPTY、`claude.ps1` 执行策略拦截、claude.exe 变成占位脚本需要修复、关闭自动更新;
  macOS:`npm install -g` 报 EACCES、npm 全局目录修复、sudo 安装 Node pkg。
  Windows 步骤于 2026-08-27 实战验证;macOS 步骤按 2026-08-29 学员实战方案编写,真机首装实录待补。
  2026-09-30 时效性复核:修正了已废弃的 autoUpdates 键与已移除的 claude config 命令。
license: MIT
metadata:
  version: "1.3"
  category: dev-environment
---

# Claude Code 安装与修复(Windows / macOS + npm 全局 + 中国网络)

> Windows 11 + PowerShell 5.1:2026-08-27 实战验证;macOS 13+ (bash 3.2):按 2026-08-29 学员实战方案编写(真机首装实录完成后将补注)。
> 相关 skill:[[dsh-install]];npm 执行策略问题的完整排查见本文第 1 节 Windows 部分(同样适用于 npm 本身)。

**2026-09-30 复核依据**（区分「实测」与「转述」）:

| 结论 | 核实方式 |
|---|---|
| Node ≥22 引擎要求未变 | `npm view` 直读包元数据，2.1.198 与 2.1.285 两版对比 |
| 平台子包名未变 | 同上，`optionalDependencies` 逐项比对 |
| `claude config` 已移除 | 实跑 `claude --help` 核对完整命令表 |
| `autoUpdates` 已废弃 | 官方 issue 明确回复 + 本机配置迁移后状态印证 |
| `DISABLE_AUTOUPDATER` 有效 | 官方文档 + `claude doctor` 实测输出 |

## 0. 前置:Node.js ≥ 22

**这是包的硬性要求**(`engines: { node: ">=22.0.0" }`,实测 2.1.285 与 2.1.198 一致,未随版本放宽)。

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

> 💡 若同时使用 [[dsh-install]],选 **v22.23.2 或更高**即可两边都满足(dsh 另需 ≥22.15)。

## 1. 平台拦截解除

**Windows:解除 PowerShell 执行策略拦截**

症状:`npm : 无法加载文件 ...npm.ps1,因为在此系统上禁止运行脚本`

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

- 不需要管理员权限;选 `RemoteSigned` 而非 `Bypass`(保留基本防护)。
- 改完必须重开终端。

**macOS:修复 npm 全局目录**

症状:`npm install -g` 报 `EACCES: permission denied`(pkg 装的 Node 归 root,/usr/local 下 npm -g 必报)。

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

- 官方不建议 `sudo npm install -g`;改 prefix 是 **npm 路线下**的根治方案(预防步骤,不是补救)。
- 仅当 `npm config get prefix` 落在 /usr/local 等 root 目录时才需要;已可写则不动。
- 改完重开终端,验证 `npm config get prefix` 已指向 ~/.npm-global。

> 💡 **官方现已不把 `~/.npm-global` prefix 作为首选。** 官方现行口径是「别用 sudo,直接换原生安装器」:
> `curl -fsSL https://claude.ai/install.sh | bash`。推荐度:原生安装器 > Homebrew(`brew install --cask claude-code`,不自动更新) > npm。
> **但国内网络下 claude.ai 直连通常不稳定**,所以本仓库仍以 **npm + 国内镜像**为主线;上面这段 prefix 修复对走 npm 路线的用户依然有效。

## 2. 安装

**Windows**:

```powershell
# 先确认没有 claude 进程在跑,否则报文件占用且会留下半成品安装
Get-Process claude   # 必须无输出;有则关闭所有 Claude Code 窗口

npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
```

**macOS**(占用检测:`pgrep -f '[c]laude'` 必须无输出;方括号防自匹配):

```bash
pgrep -f '[c]laude'   # 必须无输出;有则关闭所有 Claude Code 窗口
npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
```

> ⚠️ **用镜像站时注意**:主包依赖 **8 个平台子包**(`@anthropic-ai/claude-code-{win32,darwin,linux}-{x64,arm64}` + 两个 musl)。
> 镜像站若**没有同步全部平台包**,会出现「主包装上了但没有可执行文件」。选镜像源时确认它对 `@anthropic-ai/*` 是全量同步的。

## 3. 验证

```bash
claude --version   # 输出版本号即成功
# macOS:若 command not found,先 source ~/.zprofile 或重开终端
```

首次交互使用需要登录或配置 API key —— 见第 6 节的多模型配置模式。

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

**Windows**:`claude.exe` 是占位脚本。

症状:`Program 'claude.exe' failed to run: The specified executable is not a valid application for this OS platform`,
且 `...\claude-code\bin\claude.exe` 只有约 500 字节(内容是 "claude native binary not installed" 的 shell 提示)。

修复 —— 从同包平台二进制复制回来(该子包在 2.1.285 上**仍叫这个名字**,已核实):

```powershell
Copy-Item "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\node_modules\@anthropic-ai\claude-code-win32-x64\claude.exe" `
          "C:\Users\<用户>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe" -Force
```

判据:有效的 exe 应 >100MB 且头部为 `MZ`;占位脚本只有几百字节。

**备选修法(官方路径)**:让包自己重跑安装脚本,把二进制重新落位:

```bash
node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs"
```

> 💡 **先确认版本再说**:`claude.exe` 整体消失这类问题,官方已在 **2.1.217**(更新失败后自动还原)和 **2.1.281**(Windows 并发更新互删备份)两次修复。**先升级到最新版**,能省掉一次手工修复。

**macOS**:平台原生二进制损坏(mac 无同包备份源,不可复制还原,只能重装)

判据:`~/.npm-global/lib/node_modules/@anthropic-ai/claude-code/node_modules/@anthropic-ai/claude-code-darwin-*/claude`
应为 >50MB 且头部为 Mach-O 魔数(feedface/feedfacf/cffaedfe/cafebabe)。

修复:重跑 `npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/` 重新下载平台包。

### 4c. 安装报「文件被占用」

**两种错误码,同一个根因**:运行中的 Claude Code 锁定了自己的二进制。

| 错误码 | 说明 |
|---|---|
| `EBUSY` | 旧版常见;本仓库实测于 Windows 复现过 |
| `ENOTEMPTY` | 官方文档现行叙述的错误码 |

**处理**:**关闭所有 Claude Code 窗口**(包括正在用的会话)再装。

**若报错伴随残留目录**(`ENOTEMPTY` 常见)——先删干净再装:

```bash
rm -rf "$(npm root -g)/@anthropic-ai/claude-code"
rm -rf "$(npm root -g)/@anthropic-ai/.claude-code-"*
```

```powershell
# Windows 等价
Remove-Item "$(npm root -g)\@anthropic-ai\claude-code" -Recurse -Force
Remove-Item "$(npm root -g)\@anthropic-ai\.claude-code-*" -Recurse -Force
```

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

**官方现行方式:settings.json 的 `env` 块里设 `DISABLE_AUTOUPDATER`。**

```json
{
  "env": { "DISABLE_AUTOUPDATER": "1" }
}
```

settings.json 路径:Windows `C:\Users\<用户>\.claude\settings.json`,macOS `~/.claude/settings.json`。本仓库一键脚本步骤 7 会自动完成写入(自动合并 + 备份)。

> 🔴 **不要写顶层 `autoUpdates: false`** —— 该键**已废弃**。官方原话:"We've deprecated config `autoUpdates`"。
> 若旧配置里还有它,CLI 会自动把它**迁移**成 `env.DISABLE_AUTOUPDATER` 并从配置里删掉。
> 自查:若 `~/.claude/settings.json` 里只有 `env.DISABLE_AUTOUPDATER`、而 `~/.claude.json` 里已无 `autoUpdates`,说明迁移已完成 —— 这是**正常状态**,不是你配错了。

> 🔴 **`claude config` 命令已不存在** —— 整个子命令在 v2.0.0 被移除(此前 1.0.7 起已标记弃用)。
> 网上大量教程仍在教 `claude config set -g autoUpdates false`,**照抄会直接报未知命令**。
> 现已确认命令表为:`agents / auth / auto-mode / doctor / gateway / import / install / mcp / plugin / project / setup-token / ultrareview / update`。
> 改配置请直接编辑 settings.json,或在会话内用 `/config`。

**两种关闭强度,别选错**:

| 变量 | 效果 | 何时用 |
|---|---|---|
| `DISABLE_AUTOUPDATER=1` | 只停**后台自动检查**;`claude update` / `claude install` 仍可用 | **绝大多数情况** |
| `DISABLE_UPDATES=1` | **连手动更新一起封死** | 自己分发固定版本、要锁死版本号时 |

**验证**:重启会话后跑 `claude doctor`,应显示 ——

```
Auto-updates: disabled (set by env: DISABLE_AUTOUPDATER)
```

其他要点:

- 若用 `--settings` 自定义配置文件启动,该文件的 `env` 块也要加。
- 想保留插件自动更新、只锁 CLI 本体:可用 `FORCE_AUTOUPDATE_PLUGINS`。
- 关闭后手动更新仍可用:`claude update`,或 `npm install -g @anthropic-ai/claude-code@latest --registry=https://registry.npmmirror.com/`(注意 `@latest`,别用 `npm update -g`)。
- **不要用** `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`(捆绑禁用多项且已知有 bug)。

> ⚠️ **已知未解问题**:有用户报告在配置层级中同时设了 `DISABLE_AUTOUPDATER=1` 与旧的 `autoUpdates: false`,自动更新**仍然发生**(GitHub issue #10764、#5969)。若你也遇到"配了却还在更新",属于已知问题,不是你的配置写错了。

## 6. (可选)多模型快捷启动模式

**Windows**:PowerShell profile(`Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`)里加函数:

```powershell
function cc-ds {
    claude --settings "C:\Users\<用户>\.claude-custom.json"
}
```

**macOS**:`~/.zshrc` 加函数(作用相同):

```zsh
cc-ds() {
    claude --settings "$HOME/.claude-custom.json"
}
```

对应的 `--settings` 文件放模型/env 配置(**`sk-xxx` 是占位符,请替换为你自己的 Key**):

```json
{
  "model": "<模型名>",
  "env": {
    "ANTHROPIC_BASE_URL": "<你的服务端点>",
    "ANTHROPIC_AUTH_TOKEN": "sk-xxx",
    "ANTHROPIC_MODEL": "<模型名>",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "<模型名>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "<模型名>",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "<模型名>",
    "CLAUDE_CODE_SUBAGENT_MODEL": "<模型名>",
    "DISABLE_AUTOUPDATER": "1"
  }
}
```

> 🔴 **该文件含明文 API Key** —— 权限设为仅本人可读,**绝不 commit 进任何 git 仓库**。
>
> 🔴 **关于 `--dangerously-skip-permissions`**:该参数会跳过全部权限确认,存在被提示注入操控执行任意命令的风险。**本文档不建议使用**;如确需自动化场景,请自行评估风险并在隔离环境中运行。

## 7. 完整故障速查表

| 症状 | 根因 | 处理 |
|---|---|---|
| `npm.ps1` 禁止运行脚本 | PowerShell 执行策略 | 第 1 节:`Set-ExecutionPolicy RemoteSigned` |
| `npm install -g` 报 EACCES(mac) | npm 全局目录归 root | 第 1 节:改 prefix;或改走原生安装器 |
| 安装报 `EBUSY` / `ENOTEMPTY` | 运行中的进程锁定了二进制 | 第 4c 节:关窗口 + 清残留,**别杀 node** |
| `claude` 命令无法识别 | shim 丢失 | 第 4a 节:重建 `.cmd` / 符号链接 |
| `not a valid application for this OS platform` | 二进制是占位脚本 | 第 4b 节:复制平台二进制,或跑 `install.cjs` |
| **装了但反复自动更新回去** | 用了已废弃的 `autoUpdates` 键 | 第 5 节:改用 `env.DISABLE_AUTOUPDATER` |
| **`claude config` 报未知命令** | 该子命令已在 v2.0.0 移除 | 第 5 节:直接编辑 settings.json |
| 主包装上了但没有可执行文件 | 镜像站缺平台子包 | 第 2 节:确认镜像全量同步 8 个平台包 |
| 磁盘被 `.old.*` 撑满 | 更新中断残留 | 第 4d 节:清理备份 |
| `node -v` 版本过低 | 未达引擎要求 | 第 0 节:升到 ≥22 |
