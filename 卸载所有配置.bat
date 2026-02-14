@echo off
setlocal enabledelayedexpansion
chcp 936 >nul
title FRP 完全卸载工具

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

:: 从 XML 读取服务名
set "SERVICE_NAME=frpc"
set "XML_FILE=%~dp0frpc-WinSW.xml"
if exist "%XML_FILE%" (
    for /f "tokens=3 delims=<>" %%a in ('type "%XML_FILE%" ^| findstr "<id>"') do (
        set "rawId=%%a"
        for /f "tokens=* delims= " %%b in ("!rawId!") do set "SERVICE_NAME=%%b"
    )
)

cls
mode con cols=56 lines=20
echo ================================================
echo          FRP 服务与配置卸载工具
echo ================================================
echo.
echo  本工具将协助您清理 FRP 服务注册和临时数据。
echo.
echo  核心文件（frpc.exe/toml/WinSW.exe/xml）及版本
echo  记录将保留，方便您重新部署使用。
echo ================================================
echo.
pause

:MENU
cls
echo.
echo  请选择卸载模式：
echo ================================================
echo.
echo    [1] 完全清理（推荐）
echo        删除：服务注册、计划任务、临时文件、日志
echo        保留：frpc.exe、配置文件、WinSW程序、版本记录
echo.
echo    [2] 仅删除服务和任务（保留所有文件）
echo        （保留：所有程序文件、配置、日志、备份）
echo.
echo    [3] 仅删除自动更新计划任务
echo.
echo    [0] 取消并退出
echo ================================================
echo.
set /p uchoice=请输入选项: 

if "%uchoice%"=="1" goto FULL_UNINSTALL
if "%uchoice%"=="2" goto SERVICE_ONLY
if "%uchoice%"=="3" goto SCHEDULE_ONLY
if "%uchoice%"=="0" goto EXIT
if "%uchoice%"=="x" goto EXIT

echo 无效选项...
timeout /t 1 >nul
goto MENU

:: ==================== 模式3：仅删除计划任务 ====================

:SCHEDULE_ONLY
cls
echo.
echo [步骤 1/1] 删除自动更新计划任务...
echo.
call :DELETE_SCHEDULE
echo.
pause
goto SUMMARY

:: ==================== 模式2：仅删除服务 ====================

:SERVICE_ONLY
cls
echo.
echo [步骤 1/2] 停止并卸载服务...
echo.

sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! equ 0 (
    echo 正在停止服务 %SERVICE_NAME%...
    net stop %SERVICE_NAME% >nul 2>&1
    timeout /t 2 >nul
    echo [OK] 服务已停止
) else (
    echo [信息] 服务不存在，跳过停止步骤
)

if exist "frpc-WinSW.exe" (
    echo 正在卸载服务...
    frpc-WinSW.exe uninstall >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] 服务已卸载
    ) else (
        echo [警告] 卸载命令返回错误，可能服务已不存在
    )
) else (
    sc delete %SERVICE_NAME% >nul 2>&1
    echo [OK] 已尝试删除服务注册表项
)

echo.
echo [步骤 2/2] 删除自动更新计划任务...
echo.
call :DELETE_SCHEDULE

echo.
echo [完成] 服务和任务已清理，所有文件保留
echo.
pause
goto SUMMARY

:: ==================== 模式1：完全清理（保留核心文件+版本记录） ====================

:FULL_UNINSTALL
cls
echo.
echo [信息] 完全清理模式
echo.
echo 即将执行：
echo   - 停止并卸载系统服务 [%SERVICE_NAME%]
echo   - 删除自动更新计划任务
echo   - 清理临时文件（更新标记、缓存包）
echo   - 清空日志文件
echo.
echo [保留文件] 以下文件不会删除：
echo   frpc.exe（程序主体）
echo   frpc.toml（您的配置）
echo   frpc-WinSW.exe（服务包装器）
echo   frpc-WinSW.xml（服务配置）
echo   current_version.txt（版本记录）
echo   backups\ 目录（旧版本备份）
echo.
set /p confirm=确认执行清理吗？(输入 YES 确认): 
if /i not "%confirm%"=="YES" (
    echo 已取消操作
    pause
    goto MENU
)

echo.
echo ================================================
echo 开始执行清理...
echo ================================================
echo.

:: 步骤1：停止服务
echo [步骤 1/4] 停止服务...
sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! equ 0 (
    net stop %SERVICE_NAME% >nul 2>&1
    timeout /t 2 >nul
    echo [OK] 服务已停止
) else (
    echo [信息] 服务未运行或不存在
)

:: 步骤2：卸载服务
echo.
echo [步骤 2/4] 卸载服务注册...
if exist "frpc-WinSW.exe" (
    frpc-WinSW.exe uninstall >nul 2>&1
    echo [OK] 服务已卸载
) else (
    sc delete %SERVICE_NAME% >nul 2>&1
    echo [OK] 服务注册表已清理
)

:: 步骤3：删除计划任务
echo.
echo [步骤 3/4] 删除计划任务...
call :DELETE_SCHEDULE

:: 步骤4：清理临时数据（保留核心四文件+版本记录）
echo.
echo [步骤 4/4] 清理临时数据...
echo 正在清理生成的文件...

:: 【修改】不再删除 current_version.txt
if exist "UPDATE_AVAILABLE.txt" (
    del "UPDATE_AVAILABLE.txt"
    echo   [删除] 更新标记文件 (UPDATE_AVAILABLE.txt)
)

:: 删除下载的安装包（保留 frpc.exe）
if exist "frp_v*_windows_amd64.zip" (
    del "frp_v*_windows_amd64.zip"
    echo   [删除] 安装包缓存 (*.zip)
)

:: 清空日志（保留目录）
if exist "logs\*.log" (
    del "logs\*.log" 
    echo   [清空] 日志文件 (logs\*.log)
)

if exist "logs\*.txt" (
    del "logs\*.txt"
    echo   [清空] 临时文本 (logs\*.txt)
)

:: 清理临时更新目录（如果存在）
if exist "temp_update\" (
    rmdir /s /q "temp_update"
    echo   [删除] 临时更新目录 (temp_update\)
)

echo.
echo [OK] 清理完成
echo.
echo [保留文件清单]
if exist "frpc.exe" echo   [保留] frpc.exe（程序主体）
if exist "frpc.toml" echo   [保留] frpc.toml（配置文件）
if exist "frpc-WinSW.exe" echo   [保留] frpc-WinSW.exe（服务包装器）
if exist "frpc-WinSW.xml" echo   [保留] frpc-WinSW.xml（服务配置）
if exist "current_version.txt" echo   [保留] current_version.txt（版本记录）
if exist "backups\" echo   [保留] backups\（旧版本备份）
echo.

pause
goto SUMMARY

:: ==================== 子程序 ====================

:DELETE_SCHEDULE
schtasks /query /tn "FRP更新提醒" >nul 2>&1
if !errorlevel! neq 0 (
    echo [信息] 计划任务不存在
) else (
    schtasks /delete /tn "FRP更新提醒" /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] 计划任务已删除
    ) else (
        echo [错误] 删除失败
    )
)
goto :EOF

:SUMMARY
cls
echo.
echo ================================================
echo          清理操作完成
echo ================================================
echo.
echo 已完成：
echo   - 服务 [%SERVICE_NAME%] 已停止并卸载
echo   - 计划任务 [FRP更新提醒] 已删除
echo   - 临时文件和日志已清理
echo.
echo [保留文件]
echo   核心程序：frpc.exe, frpc-WinSW.exe
echo   配置文件：frpc.toml, frpc-WinSW.xml
echo   版本记录：current_version.txt
echo   备份目录：backups\
echo.
echo 如需重新部署，请运行"首次使用向导.bat"或直接安装服务
echo.
pause

:EXIT
exit