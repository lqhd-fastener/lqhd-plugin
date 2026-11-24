@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title LQHD 外贸客户开发专家团 - WorkBuddy Windows 安装

echo.
echo ============================================================
echo   LQHD 外贸客户开发专家团 - WorkBuddy Windows 一键安装
echo ============================================================
echo.

rem ============ 可配置项 ============
set "REPO_URL=https://github.com/lqhd-fastener/lqhd-plugin.git"
set "BRANCH=main"
set "EXPERT_DIR=lqhd-customers-finder"

rem ============ 1. 确认 PowerShell 可用 ============
where powershell >nul 2>nul
if errorlevel 1 (
    echo [错误] 未找到 PowerShell，本脚本依赖 PowerShell 下载与注册。
    echo.
    pause
    exit /b 1
)

rem ============ 2. 定位 WorkBuddy 配置目录 ============
rem 优先使用环境变量 WORKBUDDY_CONFIG_DIR，否则用 %USERPROFILE%\.workbuddy
if defined WORKBUDDY_CONFIG_DIR (
    set "WB_CONFIG=%WORKBUDDY_CONFIG_DIR%"
) else (
    set "WB_CONFIG=%USERPROFILE%\.workbuddy"
)
set "MARKET_ROOT=%WB_CONFIG%\plugins\marketplaces\my-experts"
set "TARGET_DIR=%MARKET_ROOT%\plugins\%EXPERT_DIR%"
set "MANIFEST=%MARKET_ROOT%\.codebuddy-plugin\marketplace.json"

echo [信息] WorkBuddy 配置目录：%WB_CONFIG%
echo [信息] 安装目标：%TARGET_DIR%
echo.

rem ============ 3. 临时目录 ============
set "TMP_DIR=%TEMP%\lqhd-install-%RANDOM%%RANDOM%"
mkdir "%TMP_DIR%" 2>nul
if not exist "%TMP_DIR%" (
    echo [错误] 无法创建临时目录：%TMP_DIR%
    pause
    exit /b 1
)
set "ZIP_FILE=%TMP_DIR%\plugin.zip"

rem ============ 4. 下载插件包（仓库已公开，匿名 zip 即可）============
echo [步骤 1/5] 正在从 GitHub 下载插件包...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://codeload.github.com/lqhd-fastener/lqhd-plugin/zip/refs/heads/%BRANCH%' -OutFile '%ZIP_FILE%' -UseBasicParsing } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo [错误] 下载失败，请检查网络或仓库地址。
    goto :cleanup_fail
)
if not exist "%ZIP_FILE%" (
    echo [错误] 下载后未找到压缩包。
    goto :cleanup_fail
)
echo [完成] 下载成功。

rem ============ 5. 解压 ============
echo [步骤 2/5] 正在解压...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%TMP_DIR%' -Force } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo [错误] 解压失败，压缩包可能损坏。
    goto :cleanup_fail
)

rem 找到解压后的源码目录 lqhd-plugin-main
set "SRC_DIR="
for /d %%D in ("%TMP_DIR%\lqhd-plugin-*") do set "SRC_DIR=%%~fD"
if not defined SRC_DIR (
    echo [错误] 解压后未找到 lqhd-plugin-* 目录。
    goto :cleanup_fail
)
if not exist "%SRC_DIR%\.codebuddy-plugin\plugin.json" (
    echo [错误] 插件包不完整：缺少 .codebuddy-plugin\plugin.json
    goto :cleanup_fail
)
echo [完成] 解压成功：%SRC_DIR%

rem ============ 6. 安装到专家目录 ============
echo [步骤 3/5] 正在安装到 WorkBuddy 专家目录...
if exist "%TARGET_DIR%" (
    rmdir /s /q "%TARGET_DIR%"
    if exist "%TARGET_DIR%" (
        echo [错误] 无法删除旧版本目录：%TARGET_DIR%
        goto :cleanup_fail
    )
    echo [信息] 已移除旧版本。
)
mkdir "%TARGET_DIR%" 2>nul
if not exist "%TARGET_DIR%" (
    echo [错误] 无法创建目标目录。
    goto :cleanup_fail
)
xcopy "%SRC_DIR%\*" "%TARGET_DIR%\" /E /I /H /Y /Q >nul
if errorlevel 1 (
    echo [错误] 复制文件失败。
    goto :cleanup_fail
)
echo [完成] 已安装到：%TARGET_DIR%

rem ============ 7. 写入 marketplace.json 注册项 ============
echo [步骤 4/5] 正在注册到 my-experts 专家市场...
rem 通过环境变量传路径，PowerShell 逻辑用 EncodedCommand，避免 CMD 转义问题
set "LQHD_MANIFEST=%MANIFEST%"
set "LQHD_TARGET=%TARGET_DIR%"
set "LQHD_EXPERT=%EXPERT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwB0AG8AcAAnAAoAdAByAHkAIAB7AAoAIAAgACQAcAAgAD0AIAAkAGUAbgB2ADoATABRAEgARABfAE0AQQBOAEkARgBFAFMAVAAKACAAIAAkAGQAIAA9ACAAUwBwAGwAaQB0AC0AUABhAHQAaAAgACQAcAAgAC0AUABhAHIAZQBuAHQACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAKABUAGUAcwB0AC0AUABhAHQAaAAgACQAZAApACkAIAB7ACAATgBlAHcALQBJAHQAZQBtACAALQBJAHQAZQBtAFQAeQBwAGUAIABEAGkAcgBlAGMAdABvAHIAeQAgAC0ARgBvAHIAYwBlACAALQBQAGEAdABoACAAJABkACAAfAAgAE8AdQB0AC0ATgB1AGwAbAAgAH0ACgAgACAAJABtAGoAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoATABRAEgARABfAFQAQQBSAEcARQBUACAAJwAuAGMAbwBkAGUAYgB1AGQAZAB5AC0AcABsAHUAZwBpAG4AXABwAGwAdQBnAGkAbgAuAGoAcwBvAG4AJwAKACAAIAAkAHAAbAB1AGcAIAA9ACAARwBlAHQALQBDAG8AbgB0AGUAbgB0ACAALQBMAGkAdABlAHIAYQBsAFAAYQB0AGgAIAAkAG0AagAgAC0AUgBhAHcAIAAtAEUAbgBjAG8AZABpAG4AZwAgAFUAVABGADgAIAB8ACAAQwBvAG4AdgBlAHIAdABGAHIAbwBtAC0ASgBzAG8AbgAKACAAIABpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABwACkAIAB7ACAAJABtACAAPQAgAEcAZQB0AC0AQwBvAG4AdABlAG4AdAAgAC0ATABpAHQAZQByAGEAbABQAGEAdABoACAAJABwACAALQBSAGEAdwAgAC0ARQBuAGMAbwBkAGkAbgBnACAAVQBUAEYAOAAgAHwAIABDAG8AbgB2AGUAcgB0AEYAcgBvAG0ALQBKAHMAbwBuACAAfQAKACAAIABlAGwAcwBlACAAewAgACQAbQAgAD0AIABbAHAAcwBjAHUAcwB0AG8AbQBvAGIAagBlAGMAdABdAEAAewBuAGEAbQBlAD0AJwBtAHkALQBlAHgAcABlAHIAdABzACcAOwBkAGUAcwBjAHIAaQBwAHQAaQBvAG4APQAnAG0AeQAtAGUAeABwAGUAcgB0AHMAIABtAGEAcgBrAGUAdABwAGwAYQBjAGUAIAAoAGEAdQB0AG8ALQBnAGUAbgBlAHIAYQB0AGUAZAApACcAOwBwAGwAdQBnAGkAbgBzAD0AQAAoACkAfQAgAH0ACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJABtAC4AUABTAE8AYgBqAGUAYwB0AC4AUAByAG8AcABlAHIAdABpAGUAcwBbACcAcABsAHUAZwBpAG4AcwAnAF0AKQAgAHsAIAAkAG0AIAB8ACAAQQBkAGQALQBNAGUAbQBiAGUAcgAgAC0ATgBvAHQAZQBQAHIAbwBwAGUAcgB0AHkATgBhAG0AZQAgAHAAbAB1AGcAaQBuAHMAIAAtAE4AbwB0AGUAUAByAG8AcABlAHIAdAB5AFYAYQBsAHUAZQAgAEAAKAApACAAfQAKACAAIAAkAGwAaQBzAHQAIAA9ACAAQAAoACQAbQAuAHAAbAB1AGcAaQBuAHMAKQAKACAAIAAkAHMAcgBjACAAPQAgACcALgAvAHAAbAB1AGcAaQBuAHMALwAnACAAKwAgACQAZQBuAHYAOgBMAFEASABEAF8ARQBYAFAARQBSAFQACgAgACAAJABlACAAPQAgAFsAcABzAGMAdQBzAHQAbwBtAG8AYgBqAGUAYwB0AF0AQAB7AG4AYQBtAGUAPQAkAHAAbAB1AGcALgBuAGEAbQBlADsAcwBvAHUAcgBjAGUAPQAkAHMAcgBjADsAZABlAHMAYwByAGkAcAB0AGkAbwBuAD0AJABwAGwAdQBnAC4AZABlAHMAYwByAGkAcAB0AGkAbwBuADsAdgBlAHIAcwBpAG8AbgA9ACQAcABsAHUAZwAuAHYAZQByAHMAaQBvAG4AfQAKACAAIAAkAGkAZAB4ACAAPQAgAC0AMQAKACAAIABmAG8AcgAgACgAJABpAD0AMAA7ACAAJABpACAALQBsAHQAIAAkAGwAaQBzAHQALgBDAG8AdQBuAHQAOwAgACQAaQArACsAKQAgAHsACgAgACAAIAAgAGkAZgAgACgAJABsAGkAcwB0AFsAJABpAF0ALgBuAGEAbQBlACAALQBlAHEAIAAkAHAAbAB1AGcALgBuAGEAbQBlACAALQBvAHIAIAAkAGwAaQBzAHQAWwAkAGkAXQAuAHMAbwB1AHIAYwBlACAALQBlAHEAIAAkAHMAcgBjACkAIAB7ACAAJABpAGQAeAA9ACQAaQA7ACAAYgByAGUAYQBrACAAfQAKACAAIAB9AAoAIAAgAGkAZgAgACgAJABpAGQAeAAgAC0AZwBlACAAMAApACAAewAgACQAbABpAHMAdABbACQAaQBkAHgAXQA9ACQAZQAgAH0AIABlAGwAcwBlACAAewAgACQAbABpAHMAdAArAD0AJABlACAAfQAKACAAIAAkAG0ALgBwAGwAdQBnAGkAbgBzACAAPQAgACQAbABpAHMAdAAKACAAIAAkAGoAIAA9ACAAJABtACAAfAAgAEMAbwBuAHYAZQByAHQAVABvAC0ASgBzAG8AbgAgAC0ARABlAHAAdABoACAAMQAyAAoAIAAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBXAHIAaQB0AGUAQQBsAGwAVABlAHgAdAAoACQAcAAsACAAJABqACwAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABUAGUAeAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAKAAkAGYAYQBsAHMAZQApACkAKQAKACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwBPAEsAJwAKAH0AIABjAGEAdABjAGgAIAB7AAoAIAAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACcARQBSAFIAOgAnACAAKwAgACQAXwAuAEUAeABjAGUAcAB0AGkAbwBuAC4ATQBlAHMAcwBhAGcAZQApAAoAIAAgAGUAeABpAHQAIAAxAAoAfQAKAA==" > "%TMP_DIR%\reg.out" 2>&1
findstr /b "OK" "%TMP_DIR%\reg.out" >nul
if errorlevel 1 (
    type "%TMP_DIR%\reg.out"
    echo [错误] 注册失败。
    goto :cleanup_fail
)
echo [完成] 注册成功。

rem ============ 8. 清理临时目录 ============
echo [步骤 5/5] 清理临时文件...
rmdir /s /q "%TMP_DIR%" 2>nul
echo [完成] 清理完毕。

echo.
echo ============================================================
echo   安装完成！
echo.
echo   请重启 WorkBuddy，然后在左侧「专家」-「专家团」中
echo   找到「LQHD 外贸客户开发专家团」。
echo.
echo   提醒：lqhd-mcp-server 为占位服务；实际发信需在工作目录
echo         config\mail.json 填写真实邮箱配置。
echo ============================================================
echo.
pause
exit /b 0

:cleanup_fail
rmdir /s /q "%TMP_DIR%" 2>nul
echo.
echo [失败] 安装未完成，临时文件已清理。
pause
exit /b 1
