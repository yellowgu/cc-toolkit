#!/bin/bash
# ============================================================
#  cc-toolkit / install.sh  V1.2.0
#  Claude Code 国内安装/修复一键脚本（macOS 13+，bash 3.2 兼容）
#  中国网络环境：npm 走 npmmirror 镜像，Node 走 npmmirror CDN
#  源码仓库：https://gitee.com/yellowgu/cc-toolkit
#  非官方脚本，与 Anthropic 无任何关系。每一步都会先说明再执行。
#  脚本可重入：已完成的步骤会自动跳过，可放心重跑。
#  铁律：本脚本绝不强杀任何进程（无 kill/killall 调用）。
#  DRY_RUN=1 可预演全流程（不产生任何写入）。
# ============================================================

REPO_URL='https://gitee.com/yellowgu/cc-toolkit'
NODE_VER='v22.23.2'   # npmmirror CDN 固定版本（22 线最新 LTS；失效时换 v24.19.0，URL 结构相同）
NODE_MIN=22
PKG_URL="https://cdn.npmmirror.com/binaries/node/$NODE_VER/node-$NODE_VER.pkg"
DRY_RUN="${DRY_RUN:-0}"

# ---------- 输出与错误兜底 ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  CY='\033[36m'; YE='\033[33m'; GR='\033[32m'; RE='\033[31m'; GRY='\033[90m'; RS='\033[0m'
else
  CY=''; YE=''; GR=''; RE=''; GRY=''; RS=''
fi
say()  { printf "${CY}%s${RS}\n" "$1"; }
step() { printf "\n${YE}[步骤] %s${RS}\n" "$1"; }
ok()   { printf "${GR}  [通过] %s${RS}\n" "$1"; }
warn() { printf "${YE}  [警告] %s${RS}\n" "$1"; }
bad()  { printf "${RE}  [失败] %s${RS}\n" "$1"; printf "${RE}  脚本已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。${RS}\n"; }
tip()  { printf "${GRY}  [说明] %s${RS}\n" "$1"; }
die()  { bad "$1"; exit 1; }
on_err() { bad "脚本在第 $1 行出错已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。"; exit 1; }
# 只兜底"未显式处理的失败"；不用 set -e（if 条件与 || 路径不触发 ERR，可控）
trap 'on_err $LINENO' ERR
set -o pipefail 2>/dev/null || true

# DRY_RUN 模拟执行：只打印说明，不真正执行
run() {
  local desc="$1"; shift
  if [ "$DRY_RUN" = "1" ]; then tip "[DRY_RUN 模拟] $desc"; return 0; fi
  "$@"
}

# ---------- 平台守卫 ----------
[ "$(uname -s)" = "Darwin" ] || [ "$DRY_RUN" = "1" ] || die '本脚本仅支持 macOS。Windows 请用 install.ps1（见 README）。'
if command -v sw_vers >/dev/null 2>&1; then
  SWVER=$(sw_vers -productVersion 2>/dev/null | tr -d '[:space:]') || SWVER=''
  SWMAJOR=${SWVER%%.*}
  case "$SWMAJOR" in
    ''|*[!0-9]*) ;;
    *) if [ "$SWMAJOR" -lt 13 ]; then warn "macOS 13+ 为实战验证范围，当前版本（${SWVER}）未经实测，可能失败。"; fi ;;
  esac
fi
HAS_PGREP=0; command -v pgrep >/dev/null 2>&1 && HAS_PGREP=1

# ---------- 横幅 ----------
say '================================================================'
say '  cc-toolkit V1.2.0 —— Claude Code 国内安装/修复脚本（macOS）'
say "  源码可见：$REPO_URL  （非官方，与 Anthropic 无关）"
say '================================================================'
tip '本脚本将按顺序执行：环境检测 → 装 Node(如需) → 修复 npm 全局目录(EACCES) → 关闭自动更新 → 安装 Claude Code → 故障修复自检 → 模型配置(交互) → 收尾验证'
tip '每一步都会先打印说明再执行；已完成的步骤重跑时会自动跳过。'

# ---------- 1/8 环境检测 ----------
step '1/8 环境检测'

nodeOk=0
if command -v node >/dev/null 2>&1; then
  NV=$(node -v 2>/dev/null | tr -d '[:space:]') || NV=''
  NV=${NV#v}
  MAJOR=${NV%%.*}
  case "$MAJOR" in
    ''|*[!0-9]*)
      warn 'node 存在但版本获取失败，视为缺失。' ;;
    *)
      if [ "$MAJOR" -ge "$NODE_MIN" ]; then nodeOk=1; ok "Node.js 已安装：v$NV"; else warn "Node.js 版本过低：v$NV（需要 ≥ $NODE_MIN，脚本将重装）"; fi ;;
  esac
fi
if [ "$nodeOk" = "0" ]; then tip "未检测到 Node.js ≥ $NODE_MIN，稍后步骤 2/8 将自动安装。"; fi

hasClaude=0
command -v claude >/dev/null 2>&1 && hasClaude=1
if [ "$hasClaude" = "1" ]; then
  CV=$(claude --version 2>/dev/null | head -n 1) || CV=''
  if [ -n "$CV" ]; then ok "Claude Code 已检测到：$CV"; else warn 'claude 命令存在但版本获取失败（可能已损坏），稍后步骤 6/8 会自动修复。'; fi
else
  tip '未检测到 claude 命令，稍后步骤 5/8 将自动安装。'
fi

CC_PIDS=''
if [ "$HAS_PGREP" = "1" ]; then
  # [c]laude 防自匹配 + 排除自身/父进程（安装目录路径含 "cc-toolkit" 不含 "laude"，不会误匹配）
  CC_PIDS=$(pgrep -f '[c]laude' 2>/dev/null | grep -vE "^($$|${PPID:-0})$" || true)
  if [ -n "$CC_PIDS" ]; then warn "检测到 claude 进程正在运行（PID：$(printf '%s' "$CC_PIDS" | tr '\n' ' ')）。若稍后需要安装/修复，会先提示关闭。"; fi
else
  warn '本机无 pgrep：跳过进程检测（macOS 自带 pgrep，此处为降级提示）。'
fi

SUDO_OK=0
if command -v sudo >/dev/null 2>&1; then
  sudo -n true 2>/dev/null && SUDO_OK=1
fi

# ---------- 2/8 安装 Node（仅当缺失/过旧）----------
if [ "$nodeOk" = "0" ]; then
  step '2/8 安装 Node.js（npmmirror CDN 直链，sudo 静默安装）'
  if [ "$DRY_RUN" = "1" ]; then
    tip '[DRY_RUN 模拟] 下载并安装 Node pkg。'
  else
    if [ "$SUDO_OK" = "1" ]; then tip '已通过 sudo 缓存校验，可能不再弹密码；若弹出，输入开机密码（不回显是正常的）。'
    else tip '接下来会弹出 sudo 密码提示（输入不回显是正常的）；本脚本只用 sudo 装 Node，其余步骤都不需要管理员。'; fi
    run '下载 Node pkg（约 70MB，来自 npmmirror CDN，国内快）' curl -fL "$PKG_URL" -o "$HOME/node-$NODE_VER.pkg" || die 'Node 下载失败。请检查网络后重跑；或改 v24.19.0 直链手动下载。'
    run 'sudo 静默安装 Node pkg（约 1 分钟，请勿关闭本窗口）' sudo installer -pkg "$HOME/node-$NODE_VER.pkg" -target / || die 'Node 安装失败（sudo 密码错误或网络）。重跑本脚本即可。'
    rm -f "$HOME/node-$NODE_VER.pkg"
    hash -r
    if command -v node >/dev/null 2>&1; then
      ok 'Node 已安装。'
    else
      tip 'Node 已安装但当前终端 PATH 未刷新：请重开终端后重跑本脚本继续（步骤 1-2 会自动跳过）。'
      exit 0
    fi
  fi
else
  step "2/8 安装 Node —— 已跳过（本机已有 Node ≥ $NODE_MIN）"
fi

# ---------- 3/8 修复 npm 全局目录（根治 EACCES）----------
step '3/8 修复 npm 全局目录（根治 EACCES；macOS 版"平台拦截解除"）'
PREFIX=$(npm config get prefix 2>/dev/null | tr -d '[:space:]') || PREFIX=''
case "$PREFIX" in
  /usr/local*|/usr/*)
    warn "npm 全局目录属于 root（$PREFIX）：npm install -g 会报 EACCES。官方不建议 sudo npm -g；改为用户目录根治。"
    run '创建 ~/.npm-global' mkdir -p "$HOME/.npm-global"
    run 'npm config set prefix ~/.npm-global' npm config set prefix "$HOME/.npm-global"
    if grep -qF '.npm-global/bin' "$HOME/.zprofile" 2>/dev/null; then
      tip '~/.zprofile 已有 .npm-global/bin，跳过追加。'
    elif [ "$DRY_RUN" = "1" ]; then
      tip '[DRY_RUN 模拟] 追加 export PATH 到 ~/.zprofile'
    else
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zprofile"
      tip '已追加 PATH 到 ~/.zprofile（新终端自动生效）。'
    fi
    export PATH="$HOME/.npm-global/bin:$PATH"
    ok '已切换 npm 全局目录到 ~/.npm-global（新终端自动生效，当前会话已生效）。'
    PREFIX="$HOME/.npm-global"
    ;;
  *)
    ok "npm 全局目录可写：$PREFIX（不动用户现有配置）。" ;;
esac

# ---------- 4/8 关闭自动更新 ----------
step '4/8 关闭 Claude Code 自动更新（强烈建议）'
# 实际写入在 7b 完成；此处只检查+预告（对应 Windows 版写用户级环境变量）
if [ -f "$HOME/.claude/settings.json" ] && node -e "var o=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(o.autoUpdates===false?0:1)" "$HOME/.claude/settings.json" 2>/dev/null; then
  ok '已检测到 settings.json 顶层 autoUpdates: false，跳过。'
else
  tip '本机尚未写入 autoUpdates: false（官方新键）。注意勿用 `claude config set -g`——有 bug 会存成字符串不生效。'
  tip '步骤 7/8 合并时将直接手改 JSON 写入 autoUpdates: false（布尔）并备份，同时写 env.DISABLE_AUTOUPDATER=1 兜底。'
fi

# ---------- 5/8 安装 Claude Code ----------
step '5/8 安装 Claude Code（npm 全局 + npmmirror 镜像）'
if [ "$hasClaude" = "1" ]; then
  ok '已检测到 claude 命令，跳过安装（如需重装/升级请见 README 手动步骤）。'
else
  if [ -n "$CC_PIDS" ]; then die '检测到 claude 进程正在运行：安装会报 EBUSY 且留下半成品。请关闭所有 Claude Code 窗口后重跑本脚本。（脚本不会自动强杀进程）'; fi
  run '执行 npm install -g @anthropic-ai/claude-code（npmmirror 镜像）' npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/ || die 'npm 安装失败（若报 EBUSY 请关闭所有 Claude Code 窗口重跑；其他错误请检查网络后重跑，或看 README 故障表）。'
  hash -r
  CV=$(claude --version 2>/dev/null | head -n 1) || CV=''
  if [ -n "$CV" ]; then ok "安装成功：$CV"; else warn '安装完成但 claude --version 无输出，稍后步骤 6/8 会自动修复。'; fi
fi

# ---------- 6/8 故障修复自检 ----------
step '6/8 故障修复自检（每项先检测，有故障才修复）'
PKG="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"

CLAUDE_OK=0
if command -v claude >/dev/null 2>&1; then
  claude --version >/dev/null 2>&1 && CLAUDE_OK=1
fi

# 6a. claude 命令不可用（无法识别或已损坏）→ 重建符号链接
if [ "$CLAUDE_OK" = "1" ]; then
  ok 'claude 命令可用，符号链接无需修复。'
else
  if [ -f "$PKG/cli.js" ]; then
    tip 'claude 命令不可用但包本体还在：重建符号链接。'
    if [ "$DRY_RUN" = "1" ]; then
      tip '[DRY_RUN 模拟] ln -sfn ../lib/node_modules/@anthropic-ai/claude-code/cli.js <prefix>/bin/claude'
    else
      mkdir -p "$PREFIX/bin"
      ln -sfn ../lib/node_modules/@anthropic-ai/claude-code/cli.js "$PREFIX/bin/claude"
      ok '已重建 claude 符号链接（npm 标准形态）。'
    fi
  else
    warn 'claude 命令不可用且包本体不存在：跳过符号链接修复（请先确认步骤 5/8 安装成功）。'
  fi
fi

# 6b. 平台原生二进制损坏（几百字节占位）→ 提示重装（mac 无同包备份源，与 Windows 复制还原不同）
DARWIN_BIN=$(find "$PKG" -maxdepth 4 -type f -path '*/claude-code-darwin-*/claude' 2>/dev/null | head -n 1) || DARWIN_BIN=''
if [ -n "$DARWIN_BIN" ] && [ -f "$DARWIN_BIN" ]; then
  MAGIC=$(od -An -tx1 -N4 "$DARWIN_BIN" 2>/dev/null | tr -d ' \n') || MAGIC=''
  SIZE=$(wc -c < "$DARWIN_BIN" 2>/dev/null | tr -d ' ') || SIZE=0
  case "$MAGIC" in
    feedface|feedfacf|cffaedfe|cafebabe)
      if [ "$SIZE" -gt 52428800 ]; then ok "原生二进制正常（$((SIZE/1048576))MB，Mach-O）。"
      else warn "原生二进制偏小（$SIZE 字节）：可能下载不完整，建议重跑步骤 5/8 重装。"; fi ;;
    *)
      warn "原生二进制异常（$SIZE 字节，无 Mach-O 魔数）：建议重跑步骤 5/8 重装（npm install -g 会重新下载平台包）。" ;;
  esac
else
  warn '未找到平台二进制（claude-code-darwin-*）：包可能未装完整，建议重跑脚本走安装分支。'
fi

# 6c. 残留 .old.* 垃圾（更新中断遗留，几百 MB）
OLDCOUNT=$(find "$PKG" -maxdepth 4 -type f -name 'claude.old.*' 2>/dev/null | wc -l | tr -d ' ') || OLDCOUNT=0
if [ "$OLDCOUNT" -gt 0 ]; then
  tip "发现 $OLDCOUNT 个更新残留备份（claude.old.*），确认 claude 可用后自动清理。"
  if [ "$CLAUDE_OK" = "1" ]; then
    if [ "$DRY_RUN" = "1" ]; then tip '[DRY_RUN 模拟] 删除残留备份。'
    else find "$PKG" -maxdepth 4 -type f -name 'claude.old.*' -delete 2>/dev/null || true; ok "已清理 $OLDCOUNT 个残留备份。"; fi
  else
    warn 'claude --version 尚不可用，暂不清理残留（先解决安装问题）。'
  fi
else
  ok '无残留 .old.* 备份。'
fi

# ---------- 7/8 模型配置 + settings.json 自动配置 ----------
step '7/8 模型配置（交互）+ settings.json 自动写入（自动合并 + 备份 + 可回滚）'
SETTINGS="$HOME/.claude/settings.json"

# 7a. 模型方案选择（交互；支持环境变量预置无人值守）
useDS=0
dsKey=''
if [ -n "${CC_TOOLKIT_DS_KEY:-}" ]; then
  useDS=1
  dsKey=$(printf '%s' "$CC_TOOLKIT_DS_KEY" | tr -d '[:space:]')
  tip '检测到环境变量 CC_TOOLKIT_DS_KEY，自动配置 DeepSeek 模型（无人值守模式，跳过询问）。'
  ok '已收到 Key（只写入本机 settings.json，不上传）。'
elif [ -t 0 ]; then
  say ''
  tip '模型方案选择：'
  tip '  Y = 配置 DeepSeek 模型（国内网络流畅，推荐；只需一个 DeepSeek API Key）'
  tip '  n = 跳过，稍后自行登录 Anthropic 官方账号或手工配置'
  read -r -p '是否配置 DeepSeek 模型？[Y/n]（直接回车=是）' choice || choice=''
  choice=$(printf '%s' "$choice" | tr -d '[:space:]')
  case "$choice" in
    ''|[Yy]|[Yy][Ee][Ss])
      useDS=1
      tip '请在 https://platform.deepseek.com 充值并创建 API Key（sk- 开头），粘贴后回车（输入不回显）：'
      tip '留空回车 = 本次只关自动更新，模型以后自己配。'
      IFS= read -r -s dsKey || dsKey=''
      echo ''
      dsKey=$(printf '%s' "$dsKey" | tr -d '[:space:]')
      if [ -z "$dsKey" ]; then useDS=0; warn '未输入 Key，跳过模型配置（只关自动更新）。'; else ok '已收到 Key（只写入本机 settings.json，不上传）。'; fi
      ;;
    *)
      tip '已跳过模型配置。' ;;
  esac
else
  warn '无交互终端且未预置 CC_TOOLKIT_DS_KEY：跳过模型配置（只关自动更新）。'
fi

# 7b. 合并写入（用本脚本刚保证装好的 node 做 JSON 合并，零额外依赖）
merge_settings() {
  # $1=settings 路径 $2=是否配置 DS(0/1) $3=DS Key $4=备份时间戳
  local settings="$1" use_ds="$2" ds_key="$3" ts="$4"
  if [ "$DRY_RUN" = "1" ]; then
    tip '[DRY_RUN 模拟] 合并写入 settings.json（autoUpdates: false + env 键 + 备份）。'
    return 0
  fi
  node - "$settings" "$use_ds" "$ds_key" "$ts" <<'NODEJS'
var fs = require('fs');
var path = require('path');
var argv = process.argv.slice(2);
var settingsPath = argv[0];
var useDs = argv[1] === '1';
var dsKey = argv[2];
var ts = argv[3];
var bak = settingsPath + '.bak-' + ts;
var obj = {};
if (fs.existsSync(settingsPath)) {
  fs.copyFileSync(settingsPath, bak);
  console.log('  [说明] 已备份原文件：' + bak);
  try {
    obj = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  } catch (e) {
    console.log('  [警告] 现有 settings.json 解析失败（可能不是标准 JSON），将重建为标准 JSON（原文件已备份，请自行迁移自定义配置）。');
    obj = {};
  }
}
// 顶层布尔键：必须手改 JSON（claude config set -g 有 bug 会存成字符串不生效）
obj.autoUpdates = false;
var env = (typeof obj.env === 'object' && obj.env !== null && !Array.isArray(obj.env)) ? obj.env : {};
obj.env = env;
env.DISABLE_AUTOUPDATER = '1';
env.CLAUDE_CODE_EFFORT_LEVEL = 'max';
var dsKeys = {
  ANTHROPIC_BASE_URL: 'https://api.deepseek.com/anthropic',
  ANTHROPIC_AUTH_TOKEN: dsKey,
  ANTHROPIC_MODEL: 'deepseek-v4-pro',
  ANTHROPIC_DEFAULT_OPUS_MODEL: 'deepseek-v4-pro',
  ANTHROPIC_DEFAULT_SONNET_MODEL: 'deepseek-v4-flash',
  ANTHROPIC_DEFAULT_HAIKU_MODEL: 'deepseek-v4-flash',
  ANTHROPIC_DEFAULT_FABLE_MODEL: 'deepseek-v4-pro',
  CLAUDE_CODE_SUBAGENT_MODEL: 'deepseek-v4-pro'
};
if (useDs) { Object.keys(dsKeys).forEach(function (k) { env[k] = dsKeys[k]; }); }
var dir = path.dirname(settingsPath);
if (!fs.existsSync(dir)) { fs.mkdirSync(dir, { recursive: true }); }
fs.writeFileSync(settingsPath, JSON.stringify(obj, null, 2) + '\n', 'utf8');
console.log('  改动内容：');
console.log('  autoUpdates = false（顶层布尔键）');
console.log('  env.DISABLE_AUTOUPDATER = 1');
console.log('  env.CLAUDE_CODE_EFFORT_LEVEL = max');
if (useDs) {
  Object.keys(dsKeys).forEach(function (k) {
    if (k === 'ANTHROPIC_AUTH_TOKEN') { console.log('  env.ANTHROPIC_AUTH_TOKEN = sk-***（已隐藏显示）'); }
    else { console.log('  env.' + k + ' = ' + dsKeys[k]); }
  });
}
console.log('  如需回滚：cp "' + bak + '" "' + settingsPath + '"');
console.log('  [通过] settings.json 已合并写入（其他已有配置键全部保留）。');
NODEJS
}

TS=$(date +%Y%m%d-%H%M%S)
merge_settings "$SETTINGS" "$useDS" "$dsKey" "$TS"

# ---------- 8/8 收尾 ----------
step '8/8 收尾验证'
CV=$(claude --version 2>/dev/null | head -n 1) || CV=''
if [ -n "$CV" ]; then ok "验证通过：$CV"; else warn 'claude --version 无输出，请重开终端后再验证一次。'; fi

say ''
say '================================================================'
say '  全部步骤完成。'
tip '下一步：'
tip '  1. 关闭本窗口，重新打开「终端」（让 PATH 与环境生效）'
if [ "$useDS" = "1" ]; then tip '  2. 已配置 DeepSeek 模型：重开终端后直接运行 claude 即可使用（免登录）'
else tip '  2. 运行 claude 首次交互（登录官方账号，或自行配置第三方模型，见 README FAQ）'; fi
tip '  3. 已有 Claude Code 的用户：可安装本仓库 plugin 获得自动化故障修复'
tip '     /plugin marketplace add yellowgu/cc-toolkit'
tip '     /plugin install cc-toolkit@cc-toolkit'
tip "  故障排查：$REPO_URL 的 README 故障表；或提 issue。"
say '================================================================'

# 防闪退：仅真交互终端暂停，管道/CI 不挂死
if [ "$DRY_RUN" != "1" ] && [ -t 0 ]; then printf '\n按回车键退出……'; IFS= read -r _ || true; fi
exit 0
