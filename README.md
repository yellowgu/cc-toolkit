# cc-toolkit — Claude Code 国内安装/修复工具箱

> 面向国内 Windows 用户的一键安装与故障修复工具：npmmirror 镜像安装、EBUSY/占位 exe 修复、关闭自动更新。
> **非官方项目，与 Anthropic 无任何关系**——仅分享中国网络环境下的实战经验。适用于 Windows 11 + PowerShell 5.1。

[![Gitee](https://img.shields.io/badge/Gitee-yellowgu%2Fcc--toolkit-red)](https://gitee.com/yellowgu/cc-toolkit)
[![GitHub](https://img.shields.io/badge/GitHub-yellowgu%2Fcc--toolkit-blue)](https://github.com/yellowgu/cc-toolkit)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

## 适合谁

| 你的情况 | 用哪个 |
|---|---|
| 完全小白：没装过 Node / Claude Code | 下面"一条命令安装" |
| 已有 Claude Code，但出了故障（EBUSY、`claude` 无法识别、exe 变占位脚本） | 一条命令安装（脚本自动检测+修复），或安装 Plugin 让修复自动化 |
| 只想看文档手动操作 | "手动安装步骤" + "常见故障表" |

## 一条命令安装

打开 PowerShell，粘贴整行回车（会先下载脚本到当前目录，再执行）：

```powershell
irm https://gitee.com/yellowgu/cc-toolkit/raw/main/install.ps1 -OutFile install.ps1; .\install.ps1
```

脚本会做这些事（**每一步都会先打印说明再执行**）：

1. 环境检测（Node / Claude Code / 运行中的进程）
2. 装 Node 22 LTS（仅当缺失，npmmirror CDN 直链）
3. 解除 PowerShell 执行策略拦截
4. 关闭自动更新（`DISABLE_AUTOUPDATER=1`）
5. 安装 Claude Code（npm npmmirror 镜像）
6. 故障修复自检（shim 重建、占位 exe 还原、清理残留）
7. 模型配置（**交互**：回车确认配置 DeepSeek → 粘贴 API Key，输入不回显、只写本机；也可选 n 跳过）+ settings.json 自动配置（**改前备份、合并不覆盖你的其他配置、可回滚**）
8. 收尾验证

**注意事项**：

- 脚本**可重入**：装 Node 后提示重开终端，重跑即可继续，已完成的步骤自动跳过
- 装 Node 需要**管理员权限**：若脚本提示，请右键 PowerShell"以管理员身份运行"后重跑
- 检测到 Claude Code 进程运行时，脚本会**提示关闭后重跑**，绝不强杀进程
- 装完最后会**询问是否配置 DeepSeek 模型**（国内网络推荐）：回车 → 粘贴 DeepSeek API Key（输入不回显、只写本机、不上传）→ 完成；选 n 跳过，之后可登录官方账号或手工配置
- 高级（无人值守/远程装机）：先设环境变量再跑脚本，自动跳过询问：`$env:CC_TOOLKIT_DS_KEY = 'sk-你的key'; .\install.ps1`
- 脚本来自本仓库源码，**不放心的同学可先在网页查看 install.ps1 源码**，再下载运行（两轨一致）
- 供应链说明：本脚本是"下载即执行"，请自行判断信任。所有下载地址均为固定版本（不随最新版漂移）

## 已有 Claude Code？装 Plugin 让修复自动化

在 Claude Code 会话里：

```
/plugin marketplace add yellowgu/cc-toolkit
/plugin install cc-toolkit@cc-toolkit
```

安装后，当你描述故障（如"claude 装不上 EBUSY"）时，修复 skill 会自动触发。
（本 Plugin 的定位：**修故障 > 教安装**。安装归脚本，修复归 skill。）

## 手动安装步骤

脚本每一步对应的命令（不想用脚本就照抄）：

```powershell
# 0. Node ≥ 20（无则下载安装，npmmirror CDN 直链，装完必须重开终端）
Invoke-WebRequest -Uri "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2-x64.msi" -OutFile "$env:TEMP\node-v22.23.2-x64.msi"
Start-Process msiexec.exe -ArgumentList '/i', "$env:TEMP\node-v22.23.2-x64.msi", '/qn', '/norestart' -Wait   # 需管理员

# 1. 解除执行策略拦截
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 2. 关闭自动更新（唯一有效开关）
[Environment]::SetEnvironmentVariable("DISABLE_AUTOUPDATER", "1", "User")

# 3. 安装（先确认没有 claude 进程在跑）
Get-Process claude   # 必须无输出
npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/

# 4. （可选）配置 DeepSeek 模型：%USERPROFILE%\.claude\settings.json 的 env 块
{ "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-你的key",
    "ANTHROPIC_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "deepseek-v4-pro",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-pro" } }

# 5. 验证
claude --version
```

## 常见故障表

| 症状 | 原因 | 修复 |
|---|---|---|
| `npm : 无法加载文件 ...npm.ps1，因为在此系统上禁止运行脚本` | 执行策略拦截 | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`，重开终端 |
| `npm install` 报 **EBUSY** 且留半成品 | Claude Code 正在运行锁住了 exe | 关闭**所有** Claude Code 窗口后重装 |
| `claude` 命令无法识别 | `claude.cmd` shim 丢失 | 安装脚本 6a 自动重建；手动内容见 install.ps1 |
| `Program 'claude.exe' failed to run: ... not a valid application` | `bin\claude.exe` 是 500 字节占位脚本 | 从同包 `node_modules\@anthropic-ai\claude-code-win32-x64\claude.exe` 复制回 `bin\claude.exe`（脚本 6b 自动做） |
| 更新中断留下 `claude.exe.old.*`（几百 MB） | 更新被打断 | 确认 `claude --version` 正常后删除（脚本 6c 自动做） |
| 版本总被自动更新 | 未关自动更新 | `DISABLE_AUTOUPDATER=1`（`autoUpdates` 键已废弃，勿用） |

## FAQ

**为什么用 npmmirror？** npm 官方源在国内慢/易失败，npmmirror 是国内同步镜像。

**为什么关自动更新？** 自动更新不可控（半成品、占位 exe 问题多由此来）。关闭后手动更新仍可用：
`npm install -g @anthropic-ai/claude-code@latest --registry=https://registry.npmmirror.com/`（注意 `@latest`，别用 `npm update -g`）。

**怎么卸载？** `npm uninstall -g @anthropic-ai/claude-code`。

**能配第三方模型（如 DeepSeek）吗？** 可以，而且安装脚本最后会**交互询问**——回车确认后粘贴 DeepSeek API Key 即自动配好（模型映射、base_url、token 全写入 settings.json，只写本机）。错过询问也没关系：重跑脚本即可补配，或按"手动安装步骤"第 4 步手工配置。更多模型配置玩法（`--settings` 文件、双模型快捷启动）见本仓库 skill 第 6 节（注意：该节含 `--dangerously-skip-permissions` 启动方式，仅建议单机本地自用）。

## 关于

- 作者：yellowgu（[Gitee](https://gitee.com/yellowgu) / [GitHub](https://github.com/yellowgu)）
- forge-ai 开源系列项目
- 反馈问题请提 [Issues](https://gitee.com/yellowgu/cc-toolkit/issues)
- License: MIT
