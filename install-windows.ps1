<#
.SYNOPSIS
    LQHD 外贸客户开发专家团 —— WorkBuddy Windows 一键安装脚本。

.DESCRIPTION
    从 GitHub 拉取插件包，安装到 WorkBuddy 的 my-experts 专家目录，
    并在 marketplace.json 中写入注册项。安装完成后重启 WorkBuddy 即可在「专家」中使用。

    注意：本仓库为私有仓库，匿名 zip 下载会返回 404，因此脚本默认使用 git clone，
    需要 Windows 本机已安装 git 且已登录 GitHub（Git Credential Manager 中保存了凭证）。
    若本机不便登录 git，可用 -Token 传入 GitHub Personal Access Token 走 API 下载。

.PARAMETER Token
    GitHub Personal Access Token（需 repo 读权限）。传入后改用 GitHub API 下载 zip，无需 git 登录。

.PARAMETER RepoUrl
    GitHub 仓库地址。默认 https://github.com/lqhd-fastener/lqhd-plugin.git

.PARAMETER Branch
    分支名，默认 main。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install-windows.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Token "ghp_xxxxxxxxxxxx"
#>

[CmdletBinding()]
param(
    [string]$Token,
    [string]$RepoUrl = 'https://github.com/lqhd-fastener/lqhd-plugin.git',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }

Write-Step "LQHD 外贸客户开发专家团 · WorkBuddy Windows 安装"

# ---------- 1. 定位 WorkBuddy 配置目录 ----------
$configDir = if ($env:WORKBUDDY_CONFIG_DIR) { $env:WORKBUDDY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.workbuddy' }
$marketRoot = Join-Path (Join-Path (Join-Path $configDir 'plugins') 'marketplaces') 'my-experts'
$marketDir  = Join-Path $marketRoot 'plugins'
$targetDir  = Join-Path $marketDir 'lqhd-customers-finder'
$manifestPath = Join-Path (Join-Path $marketRoot '.codebuddy-plugin') 'marketplace.json'
Write-Ok "WorkBuddy 配置目录：$configDir"

# ---------- 2. 下载到临时目录 ----------
$tmp = Join-Path $env:TEMP ('lqhd-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
    if ($RepoUrl -notmatch 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$') {
        throw "无法从 RepoUrl 解析仓库地址：$RepoUrl"
    }
    $repoOwner = $Matches[1]
    $repoName = $Matches[2]

    if ($Token) {
        # 私有仓库：用 GitHub API + Token 下载 zipball（无需 git 登录）
        Write-Step "使用 GitHub Token 下载插件压缩包..."
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/zipball/$Branch"
        $headers = @{
            'Authorization' = "token $Token"
            'Accept'        = 'application/vnd.github+json'
            'User-Agent'    = 'lqhd-plugin-installer'
        }
        $zipPath = Join-Path $tmp 'plugin.zip'
        try {
            Invoke-WebRequest -Uri $apiUrl -Headers $headers -OutFile $zipPath -UseBasicParsing
        }
        catch {
            throw "GitHub API 下载失败：$($_.Exception.Message)。请确认 Token 有效且有 repo 读权限。"
        }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tmp -Force
        $srcDir = Get-ChildItem -LiteralPath $tmp -Directory |
                  Where-Object { $_.Name -like "$repoName-*" } |
                  Select-Object -First 1
        if (-not $srcDir) { throw "解压后未找到 $repoName-* 目录，下载内容异常" }
        Write-Ok "已通过 Token 下载插件"
    }
    else {
        # 默认：git clone（私有仓库依赖本机已保存的 GitHub 凭证）
        Write-Step "使用 git clone 拉取插件（私有仓库需本机已登录 GitHub）..."
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "未找到 git。请安装 git 并登录 GitHub，或改用 -Token 参数传入 Personal Access Token。"
        }
        $repoDir = Join-Path $tmp 'repo'
        & git clone --depth 1 --branch $Branch $RepoUrl $repoDir
        if ($LASTEXITCODE -ne 0) {
            throw "git clone 失败。私有仓库请先在本机登录 GitHub（git credential manager），或改用 -Token 参数。"
        }
        $srcDir = Get-Item -LiteralPath $repoDir
        Write-Ok "已通过 git clone 拉取插件"
    }

    # ---------- 3. 校验插件包 ----------
    $pluginJsonPath = Join-Path (Join-Path $srcDir.FullName '.codebuddy-plugin') 'plugin.json'
    if (-not (Test-Path -LiteralPath $pluginJsonPath)) {
        throw "插件包缺少 .codebuddy-plugin/plugin.json，下载内容不正确"
    }
    $plugin = Get-Content -LiteralPath $pluginJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Ok "插件标识：$($plugin.name)  版本：$($plugin.version)"

    # ---------- 4. 安装到专家目录 ----------
    Write-Step "安装到 WorkBuddy 专家目录..."
    New-Item -ItemType Directory -Force -Path $marketDir | Out-Null
    if (Test-Path -LiteralPath $targetDir) {
        Remove-Item -LiteralPath $targetDir -Recurse -Force
        Write-Ok "已移除旧版本"
    }
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Get-ChildItem -LiteralPath $srcDir.FullName -Force |
        Where-Object { $_.Name -notin @('.git', '.workbuddy', '.DS_Store') } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
        }
    Write-Ok "已安装到：$targetDir"

    # ---------- 5. 注册到 marketplace.json ----------
    Write-Step "注册到 my-experts 专家市场..."
    $manifestDir = Split-Path -Parent $manifestPath
    New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null

    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    else {
        $manifest = [pscustomobject]@{
            name        = 'my-experts'
            description = 'my-experts marketplace (auto-generated)'
            plugins     = @()
        }
    }
    if (-not $manifest.PSObject.Properties['plugins']) {
        $manifest | Add-Member -NotePropertyName plugins -NotePropertyValue @()
    }

    $pluginsList = @($manifest.plugins)
    $newEntry = [pscustomobject]@{
        name        = $plugin.name
        source      = './plugins/lqhd-customers-finder'
        description = $plugin.description
        version     = $plugin.version
    }
    $found = -1
    for ($i = 0; $i -lt $pluginsList.Count; $i++) {
        if ($pluginsList[$i].name -eq $plugin.name -or
            $pluginsList[$i].source -eq './plugins/lqhd-customers-finder') {
            $found = $i
            break
        }
    }
    if ($found -ge 0) {
        $pluginsList[$found] = $newEntry
        Write-Ok "已更新已有注册项"
    }
    else {
        $pluginsList += $newEntry
        Write-Ok "已新增注册项"
    }
    $manifest.plugins = $pluginsList
    $jsonText = $manifest | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($manifestPath, $jsonText, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host ""
    Write-Host "================ 安装完成 ================" -ForegroundColor Green
    Write-Host "请重启 WorkBuddy，然后在左侧「专家」→「专家团」中找到「LQHD 外贸客户开发专家团」。" -ForegroundColor Green
    Write-Host "提醒：lqhd-mcp-server 为占位服务；实际发信需在工作目录 config/mail.json 填写真实邮箱配置。" -ForegroundColor Yellow
}
catch {
    Write-Host "`n安装失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
