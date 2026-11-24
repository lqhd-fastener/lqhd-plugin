@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title LQHD Foreign Trade Customer Development Expert Team - WorkBuddy Windows Installation

echo.
echo ============================================================
echo   LQHD Foreign Trade Customer Development Expert Team - WorkBuddy Windows One-Click Installation
echo ============================================================
echo.

rem ============ Configurable Items ============
set "REPO_URL=https://github.com/lqhd-fastener/lqhd-plugin.git"
set "BRANCH=main"
set "EXPERT_DIR=lqhd-customers-finder"

rem ============ 1. Check PowerShell Availability ============
where powershell >nul 2>nul
if errorlevel 1 (
    echo [Error] PowerShell not found. This script requires PowerShell for downloading and registration.
    echo.
    pause
    exit /b 1
)

rem ============ 2. Locate WorkBuddy Config Directory ============
rem Prefer the WORKBUDDY_CONFIG_DIR environment variable; otherwise use %USERPROFILE%\.workbuddy
if defined WORKBUDDY_CONFIG_DIR (
    set "WB_CONFIG=%WORKBUDDY_CONFIG_DIR%"
) else (
    set "WB_CONFIG=%USERPROFILE%\.workbuddy"
)
set "MARKET_ROOT=%WB_CONFIG%\plugins\marketplaces\my-experts"
set "TARGET_DIR=%MARKET_ROOT%\plugins\%EXPERT_DIR%"
set "MANIFEST=%MARKET_ROOT%\.codebuddy-plugin\marketplace.json"

echo [Info] WorkBuddy config directory: %WB_CONFIG%
echo [Info] Install target: %TARGET_DIR%
echo.

rem ============ 3. Temporary Directory ============
set "TMP_DIR=%TEMP%\lqhd-install-%RANDOM%%RANDOM%"
mkdir "%TMP_DIR%" 2>nul
if not exist "%TMP_DIR%" (
    echo [Error] Cannot create the temporary directory: %TMP_DIR%
    pause
    exit /b 1
)
set "ZIP_FILE=%TMP_DIR%\plugin.zip"

rem ============ 4. Download Plugin Package - repo is public, anonymous zip is enough ============
echo [Step 1/5] Downloading plugin package from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://codeload.github.com/lqhd-fastener/lqhd-plugin/zip/refs/heads/%BRANCH%' -OutFile '%ZIP_FILE%' -UseBasicParsing } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo [Error] Download failed. Please check your network or the repository URL.
    goto :cleanup_fail
)
if not exist "%ZIP_FILE%" (
    echo [Error] Archive not found after download.
    goto :cleanup_fail
)
echo [Done] Download succeeded.

rem ============ 5. Extract ============
echo [Step 2/5] Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%TMP_DIR%' -Force } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo [Error] Extraction failed. The archive may be corrupted.
    goto :cleanup_fail
)

rem Locate the extracted source directory lqhd-plugin-main
set "SRC_DIR="
for /d %%D in ("%TMP_DIR%\lqhd-plugin-*") do set "SRC_DIR=%%~fD"
if not defined SRC_DIR (
    echo [Error] No lqhd-plugin-* directory found after extraction.
    goto :cleanup_fail
)
if not exist "%SRC_DIR%\.codebuddy-plugin\plugin.json" (
    echo [Error] Incomplete plugin package: missing .codebuddy-plugin\plugin.json
    goto :cleanup_fail
)
echo [Done] Extraction succeeded: %SRC_DIR%

rem ============ 6. Install to Expert Directory ============
echo [Step 3/5] Installing to the WorkBuddy expert directory...
if exist "%TARGET_DIR%" (
    rmdir /s /q "%TARGET_DIR%"
    if exist "%TARGET_DIR%" (
        echo [Error] Cannot remove the old version directory: %TARGET_DIR%
        goto :cleanup_fail
    )
    echo [Info] Old version removed.
)
mkdir "%TARGET_DIR%" 2>nul
if not exist "%TARGET_DIR%" (
    echo [Error] Cannot create the target directory.
    goto :cleanup_fail
)
xcopy "%SRC_DIR%\*" "%TARGET_DIR%\" /E /I /H /Y /Q >nul
if errorlevel 1 (
    echo [Error] Failed to copy files.
    goto :cleanup_fail
)
echo [Done] Installed to: %TARGET_DIR%

rem ============ 7. Write marketplace.json Registration Entry ============
echo [Step 4/5] Registering with the my-experts marketplace...
rem Pass paths via environment variables; use EncodedCommand for the PowerShell logic to avoid CMD escaping issues
set "LQHD_MANIFEST=%MANIFEST%"
set "LQHD_TARGET=%TARGET_DIR%"
set "LQHD_EXPERT=%EXPERT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwB0AG8AcAAnAAoAdAByAHkAIAB7AAoAIAAgACQAcAAgAD0AIAAkAGUAbgB2ADoATABRAEgARABfAE0AQQBOAEkARgBFAFMAVAAKACAAIAAkAGQAIAA9ACAAUwBwAGwAaQB0AC0AUABhAHQAaAAgACQAcAAgAC0AUABhAHIAZQBuAHQACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAKABUAGUAcwB0AC0AUABhAHQAaAAgACQAZAApACkAIAB7ACAATgBlAHcALQBJAHQAZQBtACAALQBJAHQAZQBtAFQAeQBwAGUAIABEAGkAcgBlAGMAdABvAHIAeQAgAC0ARgBvAHIAYwBlACAALQBQAGEAdABoACAAJABkACAAfAAgAE8AdQB0AC0ATgB1AGwAbAAgAH0ACgAgACAAJABtAGoAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoATABRAEgARABfAFQAQQBSAEcARQBUACAAJwAuAGMAbwBkAGUAYgB1AGQAZAB5AC0AcABsAHUAZwBpAG4AXABwAGwAdQBnAGkAbgAuAGoAcwBvAG4AJwAKACAAIAAkAHAAbAB1AGcAIAA9ACAARwBlAHQALQBDAG8AbgB0AGUAbgB0ACAALQBMAGkAdABlAHIAYQBsAFAAYQB0AGgAIAAkAG0AagAgAC0AUgBhAHcAIAAtAEUAbgBjAG8AZABpAG4AZwAgAFUAVABGADgAIAB8ACAAQwBvAG4AdgBlAHIAdABGAHIAbwBtAC0ASgBzAG8AbgAKACAAIABpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABwACkAIAB7ACAAJABtACAAPQAgAEcAZQB0AC0AQwBvAG4AdABlAG4AdAAgAC0ATABpAHQAZQByAGEAbABQAGEAdABoACAAJABwACAALQBSAGEAdwAgAC0ARQBuAGMAbwBkAGkAbgBnACAAVQBUAEYAOAAgAHwAIABDAG8AbgB2AGUAcgB0AEYAcgBvAG0ALQBKAHMAbwBuACAAfQAKACAAIABlAGwAcwBlACAAewAgACQAbQAgAD0AIABbAHAAcwBjAHUAcwB0AG8AbQBvAGIAagBlAGMAdABdAEAAewBuAGEAbQBlAD0AJwBtAHkALQBlAHgAcABlAHIAdABzACcAOwBkAGUAcwBjAHIAaQBwAHQAaQBvAG4APQAnAG0AeQAtAGUAeABwAGUAcgB0AHMAIABtAGEAcgBrAGUAdABwAGwAYQBjAGUAIAAoAGEAdQB0AG8ALQBnAGUAbgBlAHIAYQB0AGUAZAApACcAOwBwAGwAdQBnAGkAbgBzAD0AQAAoACkAfQAgAH0ACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJABtAC4AUABTAE8AYgBqAGUAYwB0AC4AUAByAG8AcABlAHIAdABpAGUAcwBbACcAcABsAHUAZwBpAG4AcwAnAF0AKQAgAHsAIAAkAG0AIAB8ACAAQQBkAGQALQBNAGUAbQBiAGUAcgAgAC0ATgBvAHQAZQBQAHIAbwBwAGUAcgB0AHkATgBhAG0AZQAgAHAAbAB1AGcAaQBuAHMAIAAtAE4AbwB0AGUAUAByAG8AcABlAHIAdAB5AFYAYQBsAHUAZQAgAEAAKAApACAAfQAKACAAIAAkAGwAaQBzAHQAIAA9ACAAQAAoACQAbQAuAHAAbAB1AGcAaQBuAHMAKQAKACAAIAAkAHMAcgBjACAAPQAgACcALgAvAHAAbAB1AGcAaQBuAHMALwAnACAAKwAgACQAZQBuAHYAOgBMAFEASABEAF8ARQBYAFAARQBSAFQACgAgACAAJABlACAAPQAgAFsAcABzAGMAdQBzAHQAbwBtAG8AYgBqAGUAYwB0AF0AQAB7AG4AYQBtAGUAPQAkAHAAbAB1AGcALgBuAGEAbQBlADsAcwBvAHUAcgBjAGUAPQAkAHMAcgBjADsAZABlAHMAYwByAGkAcAB0AGkAbwBuAD0AJABwAGwAdQBnAC4AZABlAHMAYwByAGkAcAB0AGkAbwBuADsAdgBlAHIAcwBpAG8AbgA9ACQAcABsAHUAZwAuAHYAZQByAHMAaQBvAG4AfQAKACAAIAAkAGkAZAB4ACAAPQAgAC0AMQAKACAAIABmAG8AcgAgACgAJABpAD0AMAA7ACAAJABpACAALQBsAHQAIAAkAGwAaQBzAHQALgBDAG8AdQBuAHQAOwAgACQAaQArACsAKQAgAHsACgAgACAAIAAgAGkAZgAgACgAJABsAGkAcwB0AFsAJABpAF0ALgBuAGEAbQBlACAALQBlAHEAIAAkAHAAbAB1AGcALgBuAGEAbQBlACAALQBvAHIAIAAkAGwAaQBzAHQAWwAkAGkAXQAuAHMAbwB1AHIAYwBlACAALQBlAHEAIAAkAHMAcgBjACkAIAB7ACAAJABpAGQAeAA9ACQAaQA7ACAAYgByAGUAYQBrACAAfQAKACAAIAB9AAoAIAAgAGkAZgAgACgAJABpAGQAeAAgAC0AZwBlACAAMAApACAAewAgACQAbABpAHMAdABbACQAaQBkAHgAXQA9ACQAZQAgAH0AIABlAGwAcwBlACAAewAgACQAbABpAHMAdAArAD0AJABlACAAfQAKACAAIAAkAG0ALgBwAGwAdQBnAGkAbgBzACAAPQAgACQAbABpAHMAdAAKACAAIAAkAGoAIAA9ACAAJABtACAAfAAgAEMAbwBuAHYAZQByAHQAVABvAC0ASgBzAG8AbgAgAC0ARABlAHAAdABoACAAMQAyAAoAIAAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBXAHIAaQB0AGUAQQBsAGwAVABlAHgAdAAoACQAcAAsACAAJABqACwAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABUAGUAeAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAKAAkAGYAYQBsAHMAZQApACkAKQAKACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwBPAEsAJwAKAH0AIABjAGEAdABjAGgAIAB7AAoAIAAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACcARQBSAFIAOgAnACAAKwAgACQAXwAuAEUAeABjAGUAcAB0AGkAbwBuAC4ATQBlAHMAcwBhAGcAZQApAAoAIAAgAGUAeABpAHQAIAAxAAoAfQAKAA==" > "%TMP_DIR%\reg.out" 2>&1
findstr /b "OK" "%TMP_DIR%\reg.out" >nul
if errorlevel 1 (
    type "%TMP_DIR%\reg.out"
    echo [Error] Registration failed.
    goto :cleanup_fail
)
echo [Done] Registration succeeded.

rem ============ 8. Clean Up Temporary Directory ============
echo [Step 5/5] Cleaning up temporary files...
rmdir /s /q "%TMP_DIR%" 2>nul
echo [Done] Cleanup complete.

echo.
echo ============================================================
echo   Installation complete.
echo.
echo   Please restart WorkBuddy, then look under "Experts" - "Expert Teams"
echo   in the left sidebar to find "LQHD Foreign Trade Customer Development Expert Team".
echo.
echo   Note: lqhd-mcp-server is a placeholder service. To actually send emails,
echo         fill in your real email configuration in config\mail.json in the working directory.
echo ============================================================
echo.
pause
exit /b 0

:cleanup_fail
rmdir /s /q "%TMP_DIR%" 2>nul
echo.
echo [Failed] Installation incomplete. Temporary files have been cleaned up.
pause
exit /b 1
