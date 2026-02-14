@echo off
chcp 936 >nul
title FRP 更新检查

:: 自动提权
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 正在请求管理员权限...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
)
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )

cd /d "%~dp0"

echo =========================================
echo        FRP 版本检查工具
echo =========================================
echo.
echo 正在连接 GitHub 查询最新版本...
echo.

:: 调用 PS1 检查（返回 0=无更新, 1=有更新, 2=网络错误）
powershell.exe -ExecutionPolicy Bypass -File "check-update.ps1"
set "result=%errorlevel%"

if %result% == 0 (
    echo.
    echo [OK] 当前已是最新版本
    echo.
    pause
    goto END
)

if %result% == 2 (
    echo.
    echo [错误] 无法连接到 GitHub，请检查网络
    echo.
    pause
    goto END
)

:: result=1 有更新，PS1 已生成 UPDATE_AVAILABLE.txt
if not exist "UPDATE_AVAILABLE.txt" (
    echo [错误] 读取更新信息失败
    pause
    goto END
)

:: 读取版本信息
for /f "tokens=1,2 delims=|" %%a in (UPDATE_AVAILABLE.txt) do (
    set "newVer=%%a"
    set "curVer=%%b"
)

echo.
echo 发现新版本: %newVer%
echo 当前版本:   %curVer%
echo.

choice /C YN /N /M "是否立即更新? (Y=是, N=否): "

if %errorlevel% == 1 (
    echo.
    echo 正在启动更新...
    start /wait powershell.exe -ExecutionPolicy Bypass -File "auto-update-frp.ps1"
    echo.
    echo 更新流程结束
    if exist "UPDATE_AVAILABLE.txt" del "UPDATE_AVAILABLE.txt" 2>nul
) else (
    echo.
    echo 已取消更新，信息保留在 UPDATE_AVAILABLE.txt 中
)

:END
echo.
pause
exit