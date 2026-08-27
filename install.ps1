# ============================================================
#  cc-toolkit / install.ps1  V1.0.0
#  Claude Code 国内安装/修复一键脚本（Windows 11 + PowerShell 5.1）
#  中国网络环境：npm 走 npmmirror 镜像，Node 走 npmmirror CDN
#  源码仓库：https://gitee.com/yellowgu/cc-toolkit
#  非官方脚本，与 Anthropic 无任何关系。每一步都会先说明再执行。
#  脚本可重入：已完成的步骤会自动跳过，可放心重跑。
# ============================================================

$RepoUrl = 'https://gitee.com/yellowgu/cc-toolkit'
$NodeVer = 'v22.23.2'   # npmmirror CDN 固定版本（22 线最新 LTS；失效时换 v24.19.0，URL 结构相同）

function Say($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Step($msg) { Write-Host ("`n[步骤] " + $msg) -ForegroundColor Yellow }
function Ok($msg)   { Write-Host ("  [通过] " + $msg) -ForegroundColor Green }
function Warn($msg) { Write-Host ("  [警告] " + $msg) -ForegroundColor DarkYellow }
function Bad($msg)  { Write-Host ("  [失败] " + $msg) -ForegroundColor Red; Write-Host '  脚本已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。' -ForegroundColor Red }
function Tip($msg)  { Write-Host ("  [说明] " + $msg) -ForegroundColor Gray }
function Die($msg)  { Bad $msg; exit 1 }

# ---------- 横幅 ----------
Say '================================================================'
Say '  cc-toolkit V1.0.0 —— Claude Code 国内安装/修复脚本'
Say '  源码可见：' + $RepoUrl + '  （非官方，与 Anthropic 无关）'
Say '================================================================'
Tip '本脚本将按顺序执行：环境检测 → 装 Node(如需) → 解除执行策略 → 关闭自动更新 → 安装 Claude Code → 故障修复自检 → settings.json 配置 → 收尾验证'
Tip '每一步都会先打印说明再执行；已完成的步骤重跑时会自动跳过。'

# ---------- 1/8 环境检测 ----------
Step '1/8 环境检测'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Tip '当前非管理员窗口。本脚本仅在"需要安装 Node"时才要求管理员。' }

$nodeOk = $false
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    try {
        $nv = (& node -v 2>$null | Out-String).Trim()
        if ($nv -match '^v(\d+)') {
            if ([int]$Matches[1] -ge 20) { $nodeOk = $true; Ok ('Node.js 已安装：' + $nv) }
            else { Warn ('Node.js 版本过低：' + $nv + '（需要 ≥ 20，脚本将重装）') }
        }
    } catch { Warn 'node 存在但版本获取失败，视为缺失' }
}
if (-not $nodeOk) {
    if (-not $isAdmin) { Die '未检测到可用的 Node.js，而安装 Node 需要管理员权限。请关闭本窗口，右键 PowerShell"以管理员身份运行"，重新执行本脚本。' }
    Tip '未检测到 Node.js ≥ 20，稍后步骤 2/8 将自动安装。'
}

$hasClaude = $null -ne (Get-Command claude -ErrorAction SilentlyContinue)
if ($hasClaude) {
    try { Ok ('Claude Code 已检测到：' + ((& claude --version 2>$null | Out-String).Trim().Split("`n")[0])) }
    catch { Warn 'claude 命令存在但执行失败（可能已损坏），稍后步骤 6/8 会自动修复。' }
} else {
    Tip '未检测到 claude 命令，稍后步骤 5/8 将自动安装。'
}

$ccProc = @(Get-Process claude -ErrorAction SilentlyContinue)
if ($ccProc.Count -gt 0) { Warn ('检测到 ' + $ccProc.Count + ' 个 claude 进程正在运行。若稍后需要安装/修复，会先提示关闭。') }

# ---------- 2/8 安装 Node（仅当缺失/过旧）----------
if (-not $nodeOk) {
    Step '2/8 安装 Node.js（npmmirror CDN 直链，静默安装）'
    $msi = Join-Path $env:TEMP ('node-' + $NodeVer + '-x64.msi')
    Tip ('下载 ' + $NodeVer + ' 安装包（约 30MB，来自 npmmirror CDN，国内快）……')
    try {
        Invoke-WebRequest -Uri ('https://cdn.npmmirror.com/binaries/node/' + $NodeVer + '/node-' + $NodeVer + '-x64.msi') -OutFile $msi -UseBasicParsing
        Tip '下载完成，开始静默安装（需要几十秒，请勿关闭本窗口）……'
        Start-Process msiexec.exe -ArgumentList '/i', ('"' + $msi + '"'), '/qn', '/norestart' -Wait
        Tip 'Node 已安装。Windows 的 PATH 是终端启动时快照：请关闭本窗口、重新打开 PowerShell，再重跑本脚本继续（步骤 1-2 会自动跳过）。'
        exit 0
    } catch { Die 'Node 下载或安装失败。请检查网络后重跑；或改 v24.19.0 直链手动下载。' }
} else {
    Step '2/8 安装 Node —— 已跳过（本机已有 Node ≥ 20）'
}

# ---------- 3/8 解除执行策略 ----------
Step '3/8 解除 PowerShell 执行策略拦截'
Tip '症状为"npm : 无法加载文件 ...npm.ps1，因为在此系统上禁止运行脚本"。修复方法：当前用户范围设为 RemoteSigned（不需要管理员）。'
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
$pol = (Get-ExecutionPolicy -Scope CurrentUser).ToString()
if ($pol -eq 'RemoteSigned') { Ok ('执行策略已设为 ' + $pol) } else { Warn ('当前策略：' + $pol + '（若后续仍报 npm.ps1 禁止运行，请重开终端再试）') }

# ---------- 4/8 关闭自动更新 ----------
Step '4/8 关闭 Claude Code 自动更新（强烈建议）'
Tip '唯一有效开关是环境变量 DISABLE_AUTOUPDATER=1（settings.json 里的 autoUpdates 键已废弃，勿用）。写入用户级环境变量（所有 shell 生效）。'
$cur = [Environment]::GetEnvironmentVariable('DISABLE_AUTOUPDATER', 'User')
if ($cur -ne '1') {
    [Environment]::SetEnvironmentVariable('DISABLE_AUTOUPDATER', '1', 'User')
    Tip '已写入用户级环境变量（新开的终端生效）。'
} else {
    Ok 'DISABLE_AUTOUPDATER=1 已存在，跳过。'
}
if ([Environment]::GetEnvironmentVariable('DISABLE_AUTOUPDATER', 'User') -eq '1') { Ok '自检通过：环境变量已生效。' }
else { Warn '自检未读到环境变量，请重跑本脚本确认。' }

# ---------- 5/8 安装 Claude Code ----------
Step '5/8 安装 Claude Code（npm 全局 + npmmirror 镜像）'
if ($hasClaude) {
    Ok '已检测到 claude 命令，跳过安装（如需重装/升级请见 README 手动步骤）。'
} else {
    if ($ccProc.Count -gt 0) { Die '检测到 claude 进程正在运行：安装会报 EBUSY 且留下半成品。请关闭所有 Claude Code 窗口后重跑本脚本。（脚本不会自动强杀进程）' }
    Tip '执行：npm install -g @anthropic-ai/claude-code（npmmirror 镜像）……'
    npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com/
    if ($LASTEXITCODE -ne 0) { Die 'npm 安装失败（若报 EBUSY 请关闭所有 Claude Code 窗口重跑；其他错误请检查网络后重跑，或看 README 故障表）。' }
    try {
        $v = (& claude --version 2>$null | Out-String).Trim()
        if ($v) { Ok ('安装成功：' + $v) } else { Warn '安装完成但 claude --version 无输出，稍后步骤 6/8 会自动修复。' }
    } catch { Warn 'claude 命令暂时不可用，稍后步骤 6/8 会自动修复。' }
}

# ---------- 6/8 故障修复自检 ----------
Step '6/8 故障修复自检（每项先检测，有故障才修复）'
$npmRoot = Join-Path $env:APPDATA 'npm'
$pkgRoot = Join-Path $npmRoot 'node_modules\@anthropic-ai\claude-code'
$binExe  = Join-Path $pkgRoot 'bin\claude.exe'
$realExe = Join-Path $pkgRoot 'node_modules\@anthropic-ai\claude-code-win32-x64\claude.exe'

# 6a. claude 命令无法识别 → 重建 claude.cmd shim
if (-not $hasClaude) {
    if (Test-Path $realExe) {
        Tip 'claude 命令无法识别但包本体还在：重建 claude.cmd shim。'
        $shim = Join-Path $npmRoot 'claude.cmd'
        $content = '@ECHO off' + "`r`n" + 'SETLOCAL' + "`r`n" + 'SET dp0=%~dp0' + "`r`n" + '"%dp0%node_modules\@anthropic-ai\claude-code\bin\claude.exe" %*' + "`r`n"
        [System.IO.File]::WriteAllText($shim, $content, (New-Object System.Text.ASCIIEncoding))
        Ok ('已重建 claude.cmd（刻意不建 claude.ps1，避免 Restricted 策略再拦）。')
    } else {
        Warn 'claude 命令无法识别且包本体不存在：跳过 shim 修复（请先确认步骤 5/8 安装成功）。'
    }
} else {
    Ok 'claude 命令可用，shim 无需修复。'
}

# 6b. bin\claude.exe 是 500 字节占位脚本 → 从同包复制还原
if (Test-Path $binExe) {
    $len = (Get-Item $binExe).Length
    $isMZ = $false
    try {
        $fs = [System.IO.File]::OpenRead($binExe); $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2); $fs.Close()
        $isMZ = ($b[0] -eq 0x4D -and $b[1] -eq 0x5A)
    } catch { $isMZ = $false }
    if ($len -gt 100MB -and $isMZ) {
        Ok ('bin\claude.exe 正常（' + [math]::Round($len/1MB) + 'MB，MZ 头）。')
    } else {
        Warn ('bin\claude.exe 异常（' + $len + ' 字节）：是 500 字节占位脚本，开始修复……')
        if (Test-Path $realExe) {
            Copy-Item $realExe $binExe -Force
            $len2 = (Get-Item $binExe).Length
            if ($len2 -gt 100MB) { Ok ('修复完成：exe 已还原为 ' + [math]::Round($len2/1MB) + 'MB。') }
            else { Die '修复后 exe 仍异常，请查看 README 故障表或提 issue。' }
        } else { Die '同包平台二进制缺失，无法自动修复。请重跑步骤 5/8 重装后重试。' }
    }
} else {
    Warn '未找到 bin\claude.exe（包可能未装完整），建议重跑脚本走安装分支。'
}

# 6c. 残留 .old.* 垃圾（更新中断遗留，几百 MB）
$olds = @(Get-ChildItem (Join-Path $pkgRoot 'bin') -Filter 'claude.exe.old.*' -ErrorAction SilentlyContinue)
if ($olds.Count -gt 0) {
    Tip ('发现 ' + $olds.Count + ' 个更新残留备份（claude.exe.old.*），确认 claude 可用后自动清理。')
    $ok = $false
    try { $v = (& claude --version 2>$null | Out-String).Trim(); if ($v) { $ok = $true } } catch {}
    if ($ok) {
        $olds | Remove-Item -Force
        Ok ('已清理 ' + $olds.Count + ' 个残留备份。')
    } else { Warn 'claude --version 尚不可用，暂不清理残留（先解决安装问题）。' }
} else {
    Ok '无残留 .old.* 备份。'
}

# ---------- 7/8 settings.json 自动配置 ----------
Step '7/8 settings.json 写入 DISABLE_AUTOUPDATER（自动合并 + 备份 + 可回滚）'
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$bak = $settingsPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$targetJson = @"
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  }
}
"@
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath $bak -Force
    Tip ('已备份原文件：' + $bak)
    try {
        $raw = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
        $obj = $raw | ConvertFrom-Json
        if (-not $obj.PSObject.Properties['env']) { $obj | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $obj.env.PSObject.Properties['DISABLE_AUTOUPDATER']) { $obj.env | Add-Member -NotePropertyName DISABLE_AUTOUPDATER -NotePropertyValue '1' }
        else { $obj.env.DISABLE_AUTOUPDATER = '1' }
        $out = $obj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding $false))
        Tip '改动内容：env.DISABLE_AUTOUPDATER = 1（关闭自动更新，唯一有效开关）。其他已有配置键全部保留。'
        Tip ('如需回滚：Copy-Item "' + $bak + '" "' + $settingsPath + '"')
        Ok 'settings.json 已合并写入。'
    } catch {
        Warn 'settings.json 解析失败（可能不是标准 JSON），未改动该文件，避免破坏你的配置。'
        Tip '请手工在 settings.json 中加：{"env": {"DISABLE_AUTOUPDATER": "1"}}'
        Tip ('原文件备份仍在：' + $bak)
    }
} else {
    New-Item -ItemType Directory -Path (Split-Path $settingsPath) -Force | Out-Null
    [System.IO.File]::WriteAllText($settingsPath, $targetJson, (New-Object System.Text.UTF8Encoding $false))
    Tip 'settings.json 不存在，已新建（含 env.DISABLE_AUTOUPDATER=1）。'
    Ok 'settings.json 已创建。'
}

# ---------- 8/8 收尾 ----------
Step '8/8 收尾验证'
try {
    $v = (& claude --version 2>$null | Out-String).Trim()
    if ($v) {
        Ok ('验证通过：' + $v)
    } else { Warn 'claude --version 无输出，请重开终端后再验证一次。' }
} catch { Warn 'claude 命令不可用，请重开终端后再验证；仍失败请查 README 故障表。' }

Say ''
Say '================================================================'
Say '  全部步骤完成。'
Tip '下一步：'
Tip '  1. 关闭本窗口，重新打开 PowerShell（让环境变量与 PATH 生效）'
Tip '  2. 运行 claude 首次交互（登录或配 API key，见 README FAQ）'
Tip '  3. 已有 Claude Code 的用户：可安装本仓库 plugin 获得自动化故障修复'
Tip '     /plugin marketplace add yellowgu/cc-toolkit'
Tip '     /plugin install cc-toolkit@cc-toolkit'
Tip '  故障排查：' + $RepoUrl + ' 的 README 故障表；或提 issue。'
Say '================================================================'
