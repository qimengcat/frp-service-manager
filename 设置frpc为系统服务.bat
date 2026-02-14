@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

:: ==================== 配置区 ====================
set "XML_FILE=%~dp0frpc-WinSW.xml"
set "SERVICE_NAME=frpc"
set "SCHEDULE_TASK_NAME=FRP更新提醒"

if exist "%XML_FILE%" (
    for /f "tokens=3 delims=<>" %%a in ('type "%XML_FILE%" ^| findstr "<id>"') do (
        set "rawId=%%a"
        for /f "tokens=* delims= " %%b in ("!rawId!") do set "SERVICE_NAME=%%b"
        goto :GOT_ID
    )
)
:GOT_ID

set "WINSW_EXE=%~dp0frpc-WinSW.exe"
:: ================================================

:: 自动请求管理员权限
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 正在请求管理员权限...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
)
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )

:MENU
cls
mode con cols=52 lines=24
title frpc服务管理器 [%SERVICE_NAME%]

echo.
echo  当前服务名: %SERVICE_NAME%
echo ============================================
echo.
echo    [1] 安装服务      [6] 打开服务管理器
echo    [2] 启动服务      [7] 检查FRP更新
echo    [3] 停止服务      [8] 删除服务
echo    [4] 重启服务      [9] 管理自动更新任务
echo    [5] 查看详细状态  [0] 退出
echo ============================================
echo.

call :CHECK_STATUS silent
if "%SERVICE_STATUS%"=="RUNNING" (
    echo  当前状态: [运行中]
) else if "%SERVICE_STATUS%"=="STOPPED" (
    echo  当前状态: [已停止]
) else (
    echo  当前状态: [未安装]
)
echo.
set /p choice=请输入选项: 

if "%choice%"=="1" goto INSTALL
if "%choice%"=="2" goto START
if "%choice%"=="3" goto STOP
if "%choice%"=="4" goto RESTART
if "%choice%"=="5" goto STATUS
if "%choice%"=="6" goto OPEN_SVC
if "%choice%"=="7" goto CHECK_UPDATE
if "%choice%"=="8" goto UNINSTALL
if "%choice%"=="9" goto MANAGE_SCHEDULE
if "%choice%"=="0" goto EXIT
if "%choice%"=="x" goto EXIT

echo 无效选项...
timeout /t 1 >nul
goto MENU

:: ==================== 原有功能模块 ====================

:INSTALL
cls
echo.
if exist "%WINSW_EXE%" (
    "%WINSW_EXE%" install
    if !errorlevel! equ 0 (
        echo [OK] 服务安装成功
    ) else (
        echo [错误] 安装失败
    )
) else (
    echo [错误] 未找到 frpc-WinSW.exe
)
pause
goto MENU

:START
cls
echo.
net start %SERVICE_NAME% >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] 服务启动成功
) else (
    echo [错误] 启动失败
)
pause
goto MENU

:STOP
cls
echo.
net stop %SERVICE_NAME% >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] 服务已停止
) else (
    echo [错误] 停止失败
)
pause
goto MENU

:RESTART
cls
echo.
echo 正在重启服务...
net stop %SERVICE_NAME% >nul 2>&1
timeout /t 2 >nul
net start %SERVICE_NAME% >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] 重启成功
) else (
    echo [错误] 重启失败
)
pause
goto MENU

:STATUS
cls
echo.
echo ========== 服务详细信息 ==========
sc query %SERVICE_NAME%
echo.
echo ========== 进程信息 ==========
tasklist | findstr /i "frpc"
echo.
echo 配置文件: %~dp0frpc.toml
pause
goto MENU

:OPEN_SVC
start services.msc
goto MENU

:CHECK_UPDATE
cls
echo.
echo 正在调用更新检查...
if exist "%~dp0检查更新.bat" (
    start "" "%~dp0检查更新.bat"
) else (
    echo [错误] 未找到 检查更新.bat
    pause
)
goto MENU

:UNINSTALL
cls
echo.
echo [警告] 即将删除服务: %SERVICE_NAME%
echo.
set /p confirm=确认删除吗?(输入 YES 确认): 
if /i not "%confirm%"=="YES" (
    echo 已取消删除
    pause
    goto MENU
)

call :CHECK_STATUS silent
if "%SERVICE_STATUS%"=="RUNNING" (
    echo 正在停止服务...
    net stop %SERVICE_NAME% >nul 2>&1
    timeout /t 2 >nul
)

if exist "%WINSW_EXE%" (
    "%WINSW_EXE%" uninstall
    if !errorlevel! equ 0 (
        echo [OK] 服务已删除
    ) else (
        echo [错误] 删除失败
    )
) else (
    echo [错误] 未找到 WinSW 程序
)
pause
goto MENU

:: ==================== 新增：自动更新任务管理 ====================

:MANAGE_SCHEDULE
cls
mode con cols=52 lines=20
title 管理自动更新任务

:: 检查任务是否存在
schtasks /query /tn "%SCHEDULE_TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    set "TASK_STATUS=已安装"
    for /f "tokens=2 delims=: " %%a in ('schtasks /query /tn "%SCHEDULE_TASK_NAME%" /fo list ^| findstr "下次运行时间"') do (
        set "TASK_NEXT_TIME=%%a"
    )
) else (
    set "TASK_STATUS=未安装"
    set "TASK_NEXT_TIME=N/A"
)

echo.
echo    自动更新任务管理
echo ============================================
echo.
echo    当前状态: %TASK_STATUS%
echo    任务名称: %SCHEDULE_TASK_NAME%
echo    下次运行: %TASK_NEXT_TIME%
echo.
echo    [1] 安装/修改任务时间
echo    [2] 删除任务
echo    [3] 立即执行一次（测试）
echo    [4] 打开任务计划程序
echo.
echo    [0] 返回主菜单
echo ============================================
echo.
set /p schoice=请输入选项: 

if "%schoice%"=="1" goto SCHEDULE_INSTALL
if "%schoice%"=="2" goto SCHEDULE_DELETE
if "%schoice%"=="3" goto SCHEDULE_RUN
if "%schoice%"=="4" goto SCHEDULE_OPEN
if "%schoice%"=="0" goto MENU
if "%schoice%"=="x" goto MENU

echo 无效选项...
timeout /t 1 >nul
goto MANAGE_SCHEDULE
:SCHEDULE_INSTALL
cls
echo.
echo    安装自动更新任务
echo ============================================
echo.
echo 该任务将每天自动检查 FRP 是否有新版本，
echo 并在发现更新时弹窗提示您。
echo.

:: 输入时间
:INPUT_TIME
set "taskTime=09:00"
set /p userInput=请输入每日检查时间(24小时制 HH:MM，直接回车默认09:00): 

if "!userInput!"=="" (
    set "taskTime=09:00"
    echo 使用默认时间: 09:00
) else (
    set "taskTime=!userInput!"
    
    if not "!taskTime:~2,1!"==":" (
        echo [错误] 格式应为 HH:MM（如 09:00）
        goto INPUT_TIME
    )
    
    set "hh=!taskTime:~0,2!"
    set "mm=!taskTime:~3,2!"
    
    echo !hh!| findstr /r "^[0-9][0-9]$" >nul || (echo [错误] 小时必须是数字 && goto INPUT_TIME)
    echo !mm!| findstr /r "^[0-9][0-9]$" >nul || (echo [错误] 分钟必须是数字 && goto INPUT_TIME)
    
    set /a hhNum=1!hh!-100 2>nul
    set /a mmNum=1!mm!-100 2>nul
    
    if !hhNum! gtr 23 (
        echo [错误] 小时不能超过23
        goto INPUT_TIME
    )
    if !mmNum! gtr 59 (
        echo [错误] 分钟不能超过59
        goto INPUT_TIME
    )
    
    echo 已设置时间: !taskTime!
)

echo.
echo 正在安装任务（每天 !taskTime!）...

:: 先删除旧任务（避免冲突）
schtasks /delete /tn "%SCHEDULE_TASK_NAME%" /f >nul 2>&1

:: 创建新任务
schtasks /create ^
    /tn "%SCHEDULE_TASK_NAME%" ^
    /tr "cmd /c \"%~dp0检查更新.bat\"" ^
    /sc daily ^
    /st !taskTime! ^
    /ru SYSTEM ^
    /f >nul 2>&1

if !errorlevel! equ 0 (
    echo [OK] 任务安装成功！
    echo.
    echo 提示：
    echo   - 任务将在每天 !taskTime! 自动运行
    echo   - 如需弹窗提醒，请在任务计划程序中设置"只在用户登录时运行"
    echo   - 下次开机后任务会自动生效
) else (
    echo [错误] 安装失败！
)

pause
goto MANAGE_SCHEDULE

:SCHEDULE_DELETE
cls
echo.
schtasks /query /tn "%SCHEDULE_TASK_NAME%" >nul 2>&1
if !errorlevel! neq 0 (
    echo [提示] 任务不存在，无需删除
    pause
    goto MANAGE_SCHEDULE
)

echo [警告] 即将删除自动更新任务: %SCHEDULE_TASK_NAME%
echo.
set /p confirm=确认删除吗?(输入 YES 确认): 
if /i not "%confirm%"=="YES" (
    echo 已取消删除
    pause
    goto MANAGE_SCHEDULE
)

schtasks /delete /tn "%SCHEDULE_TASK_NAME%" /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] 任务已删除
) else (
    echo [错误] 删除失败
)

pause
goto MANAGE_SCHEDULE

:SCHEDULE_RUN
cls
echo.
echo 正在立即执行一次检查（测试）...
echo.
if exist "%~dp0检查更新.bat" (
    start "" "%~dp0检查更新.bat"
    echo [OK] 已启动检查程序
) else (
    echo [错误] 未找到 检查更新.bat
)
pause
goto MANAGE_SCHEDULE

:SCHEDULE_OPEN
start taskschd.msc
goto MANAGE_SCHEDULE

:EXIT
exit

:CHECK_STATUS
set "SERVICE_STATUS=NOT_FOUND"
for /f "tokens=2 delims=: " %%a in ('sc query %SERVICE_NAME% ^| findstr /i "STATE"') do (
    set /a statecode=%%a 2>nul
    if !statecode! equ 4 set "SERVICE_STATUS=RUNNING"
    if !statecode! equ 1 set "SERVICE_STATUS=STOPPED"
)
if "%~1"=="" (
    echo 服务状态: %SERVICE_STATUS%
)
goto :EOF