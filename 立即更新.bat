@echo off
chcp 936 >nul
title FRP 立即更新

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

echo ===================================
echo    FRP 全自动更新
echo ===================================
echo.
echo 正在执行更新，请耐心等待...
echo 如遇卡住请勿关闭，正在下载或停止服务中...
echo.

:: 直接调用（非后台），等待完成
powershell.exe -ExecutionPolicy Bypass -File "auto-update-frp.ps1"
set "exitCode=%errorlevel%"

echo.
if %exitCode% equ 0 (
    echo [成功] 更新完成！
) else (
    echo [错误] 更新过程出现异常（代码: %exitCode%）
    echo 请查看日志: logs\frp-update.log
)
pause