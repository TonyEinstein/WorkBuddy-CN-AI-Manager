@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WorkBuddy Manager / WorkBuddy 管理工具

rem ============================================================
rem  WorkBuddy Dual Version Manager
rem  国内版(WorkBuddy) + 国际版(WorkBuddy AI) 共存/更新控制
rem  文件编码: GBK (ANSI) —— 中文 Windows 正常显示，英文 Windows 英文可读
rem ============================================================

rem ---- 路径定义 ----
set "CN_DIR=%LOCALAPPDATA%\Programs\WorkBuddy"
set "AI_DIR=%LOCALAPPDATA%\Programs\WorkBuddyAI"
set "CN_PRODUCT=%CN_DIR%\resources\app.asar.unpacked\cli\product.json"
set "AI_PRODUCT=%AI_DIR%\resources\app.asar.unpacked\cli\product.json"
set "AI_CACHE=%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"
set "UPDATER_DIR=%LOCALAPPDATA%\@genieworkbuddy-desktop-updater"
set "TEMP_UPDATE=%LOCALAPPDATA%\Temp\workbuddy-update-x64"
set "PSFIX=%TEMP%\wb-fix.ps1"
set "PSINFO=%TEMP%\wb-info.ps1"

rem ============================================================
rem  主菜单
rem ============================================================
:menu
cls
echo ============================================================
echo   WorkBuddy Dual Version Manager
echo   WorkBuddy 双版本 共存/更新控制 工具
echo ============================================================
echo   [1] Fix and Disable Auto-Update    修复并关闭自动升级
echo   [2] Restore Manual Update          恢复手动更新
echo   [3] Show Key Info                  查看关键信息
echo   [0] Exit                           退出
echo ------------------------------------------------------------
set "ch="
set /p "ch=  Please choose [0-3] / 请选择 [0-3] : "
if "%ch%"=="1" goto :fix
if "%ch%"=="2" goto :restore
if "%ch%"=="3" goto :info
if "%ch%"=="0" goto :end
goto :menu

rem ============================================================
rem  选项 1：修复并关闭自动升级
rem ============================================================
:fix
cls
echo ============================================================
echo   [1] Fix and Disable Auto-Update
echo       修复并关闭自动升级
echo ============================================================
echo.
echo   NOTE: Please close both WorkBuddy apps first.
echo   提示：请先关闭两个 WorkBuddy 软件再执行。
echo.

echo [Step 1/5] Detect install dirs / 检测安装目录
if exist "%CN_PRODUCT%" (echo     [OK] WorkBuddy [CN]    detected / 检测到国内版) else (echo     [SKIP] WorkBuddy [CN]    not found / 未检测到国内版)
if exist "%AI_PRODUCT%" (echo     [OK] WorkBuddy AI      detected / 检测到国际版) else (echo     [SKIP] WorkBuddy AI      not found / 未检测到国际版)
echo.

echo [Step 2/5] Backup + disable startup force update
echo            备份并关闭启动强制更新
> "%PSFIX%" echo $ErrorActionPreference='Stop'
>> "%PSFIX%" echo $enc=New-Object System.Text.UTF8Encoding($false)
>> "%PSFIX%" echo $ts=Get-Date -Format 'yyyyMMdd-HHmmss'
>> "%PSFIX%" echo $bkDir=Join-Path $env:LOCALAPPDATA 'Programs\workbuddy-fix-backup'
>> "%PSFIX%" echo $null=New-Item -ItemType Directory -Path $bkDir -Force
>> "%PSFIX%" echo $cn=Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json'
>> "%PSFIX%" echo $ai=Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json'
>> "%PSFIX%" echo $items=@(@($cn,'product-cn'),@($ai,'product-ai'))
>> "%PSFIX%" echo foreach($it in $items){
>> "%PSFIX%" echo $p=$it[0]
>> "%PSFIX%" echo $nm=$it[1]
>> "%PSFIX%" echo if(Test-Path $p){
>> "%PSFIX%" echo Copy-Item $p (Join-Path $bkDir ($nm+'-'+$ts+'.json')) -Force
>> "%PSFIX%" echo $c=[IO.File]::ReadAllText($p)
>> "%PSFIX%" echo if($c -match 'startupForceAutoUpdate'){
>> "%PSFIX%" echo $n=$c -replace '"startupForceAutoUpdate"\s*:\s*true','"startupForceAutoUpdate": false'
>> "%PSFIX%" echo } else {
>> "%PSFIX%" echo $n=$c -replace '("checkVersion"\s*:\s*\{\s*"scene"\s*:\s*"saas"\s*\})', "`$1,`n    `"startupForceAutoUpdate`": false"
>> "%PSFIX%" echo }
>> "%PSFIX%" echo if($n -ne $c){ [IO.File]::WriteAllText($p,$n,$enc); Write-Output ($nm+': disabled') } else { Write-Output ($nm+': already false') }
>> "%PSFIX%" echo } else {
>> "%PSFIX%" echo Write-Output ($nm+': MISSING (skipped)')
>> "%PSFIX%" echo }
>> "%PSFIX%" echo }
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFIX%"
del "%PSFIX%" 2>nul
echo.

echo [Step 3/5] Remove polluted AI cache / 删除国际版污染缓存
if exist "%AI_CACHE%" (
  del "%AI_CACHE%" 2>nul
  echo     [OK] Removed polluted cache / 已删除,下次启动会自动重建
) else (
  echo     [SKIP] Cache not found / 缓存不存在,无需处理
)
echo.

echo [Step 4/5] Clean residual update packages / 清理残留更新包
set "CLEANED=0"
if exist "%UPDATER_DIR%\installer.exe" (
  del "%UPDATER_DIR%\installer.exe" 2>nul
  set "CLEANED=1"
)
if exist "%TEMP_UPDATE%" (
  rd /s /q "%TEMP_UPDATE%" 2>nul
  set "CLEANED=1"
)
if "!CLEANED!"=="1" (echo     [OK] Residual packages cleaned / 已清理残留安装包) else (echo     [SKIP] No residual found / 无残留)
echo.

echo [Step 5/5] Set update-block env var / 设置更新拦截环境变量
setx WORKBUDDY_UPDATE_URL "http://127.0.0.1:9" >nul
echo     [OK] WORKBUDDY_UPDATE_URL = http://127.0.0.1:9
echo.
echo ============================================================
echo   DONE / 全部完成
echo ------------------------------------------------------------
echo   Please restart both apps and verify:
echo   请重启两个软件后验证：
echo     - Both open / login / UI correct
echo       两个软件能正常打开、登录、界面各自正确
echo     - No auto-update
echo       不再自动更新
echo ============================================================
echo.
pause
goto :menu

rem ============================================================
rem  选项 2：恢复手动更新
rem ============================================================
:restore
cls
echo ============================================================
echo   [2] Restore Manual Update / 恢复手动更新
echo ============================================================
echo.
echo   WARNING / 重要提示：
echo   This will DELETE the env var WORKBUDDY_UPDATE_URL.
echo   将删除环境变量 WORKBUDDY_UPDATE_URL。
echo.
echo   After delete / 删除后：
echo     - Periodic auto-update and manual check WILL resume.
echo       定时自动更新和手动检查更新会恢复
echo       (startup force-update is still disabled by product.json)
echo       （启动强制更新仍被 product.json 关着）
echo     - AI in-app update has a platform-mismatch bug, may
echo       download the CN package and overwrite itself!
echo       国际版应用内更新有 platform 错位 bug，可能下载国内版包覆盖自己！
echo.
echo   Safer way / 更安全方式：
echo     Download installers from official sites, then re-run [1].
echo     去各自官网下载安装包手动安装，装完再运行选项 [1]。
echo ------------------------------------------------------------
set "yn="
set /p "yn=  Confirm delete? / 确认删除？[Y/N] : "
if /i not "!yn!"=="Y" (
  echo.
  echo   Cancelled / 已取消
  echo.
  pause
  goto :menu
)
reg delete "HKCU\Environment" /v "WORKBUDDY_UPDATE_URL" /f >nul 2>&1
if errorlevel 1 (
  echo.
  echo   [INFO] Env var not found already removed / 环境变量未找到
) else (
  echo.
  echo   [OK] Deleted WORKBUDDY_UPDATE_URL / 已删除环境变量
)
echo.
echo   Note / 提示：需重启程序或重新登录 Windows 才彻底生效。
echo   Reminder / 提醒：更新完成后建议重新运行选项 [1]。
echo.
pause
goto :menu

rem ============================================================
rem  选项 3：查看当前两版本关键信息
rem ============================================================
:info
cls
echo ============================================================
echo   [3] Key Info / 关键信息
echo ============================================================
echo.

> "%PSINFO%" echo $cn=Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json'
>> "%PSINFO%" echo $ai=Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json'
>> "%PSINFO%" echo $cache=Join-Path $env:USERPROFILE '.workbuddy-ai\cache\acc-product-config-v3.json'
>> "%PSINFO%" echo $cnSU='MISSING'
>> "%PSINFO%" echo $aiSU='MISSING'
>> "%PSINFO%" echo $ep='MISSING'
>> "%PSINFO%" echo $su='MISSING'
>> "%PSINFO%" echo $mx='MISSING'
>> "%PSINFO%" echo if(Test-Path $cn){try{$d=ConvertFrom-Json (Get-Content $cn -Raw -Encoding UTF8);$cnSU=[string]$d.updates.startupForceAutoUpdate}catch{$cnSU='ERR'}}
>> "%PSINFO%" echo if(Test-Path $ai){try{$d=ConvertFrom-Json (Get-Content $ai -Raw -Encoding UTF8);$aiSU=[string]$d.updates.startupForceAutoUpdate}catch{$aiSU='ERR'}}
>> "%PSINFO%" echo if(Test-Path $cache){try{$d=ConvertFrom-Json (Get-Content $cache -Raw -Encoding UTF8);$ep=[string]$d.endpoint;$su=[string]$d.updates.startupForceAutoUpdate;$mx=[string]$d.win32MutexName}catch{$ep='ERR';$su='ERR';$mx='ERR'}}
>> "%PSINFO%" echo Write-Output ('CNSU='+$cnSU)
>> "%PSINFO%" echo Write-Output ('AISU='+$aiSU)
>> "%PSINFO%" echo Write-Output ('EP='+$ep)
>> "%PSINFO%" echo Write-Output ('SU='+$su)
>> "%PSINFO%" echo Write-Output ('MX='+$mx)

set "CNSU="
set "AISU="
set "EP="
set "SU="
set "MX="
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PSINFO%"') do (
  if "%%A"=="CNSU" set "CNSU=%%B"
  if "%%A"=="AISU" set "AISU=%%B"
  if "%%A"=="EP"   set "EP=%%B"
  if "%%A"=="SU"   set "SU=%%B"
  if "%%A"=="MX"   set "MX=%%B"
)
del "%PSINFO%" 2>nul

echo [Installed / 已安装]
if exist "%CN_DIR%\WorkBuddy.exe"   (echo   WorkBuddy [CN]    : YES / 已安装) else (echo   WorkBuddy [CN]    : NO / 未安装)
if exist "%AI_DIR%\WorkBuddyAI.exe" (echo   WorkBuddy AI      : YES / 已安装) else (echo   WorkBuddy AI      : NO / 未安装)
echo.

echo [startupForceAutoUpdate / 启动强制更新开关]
echo   CN product.json : !CNSU!
echo   AI product.json : !AISU!
echo.

echo [AI cache / 国际版缓存（污染判断）]
echo   endpoint         : !EP!
echo   startupForceAutoUpdate : !SU!
echo   win32MutexName   : !MX!
echo.

echo [Env var / 更新拦截环境变量]
reg query "HKCU\Environment" /v "WORKBUDDY_UPDATE_URL" 2>nul | findstr /C:"WORKBUDDY_UPDATE_URL" >nul 2>&1
if errorlevel 1 (
  echo   WORKBUDDY_UPDATE_URL : NOT SET / 未设置
) else (
  reg query "HKCU\Environment" /v "WORKBUDDY_UPDATE_URL" 2>nul | findstr /C:"WORKBUDDY_UPDATE_URL"
)
echo.

echo [Residual / 残留更新包]
if exist "%UPDATER_DIR%\installer.exe" (echo   updater installer.exe : YES / 有) else (echo   updater installer.exe : NO / 无)
echo.
echo ============================================================
echo.
pause
goto :menu

rem ============================================================
:end
endlocal
exit /b
