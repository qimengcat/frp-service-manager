@echo off
chcp 936 >nul 2>&1
setlocal enabledelayedexpansion
title FRP 服务管理器 - 首次使用向导

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

cls
echo =========================================
echo     FRP 服务管理器 - 首次使用向导
echo =========================================
echo:
echo 正在自动检查并初始化，请稍候...
echo:

:: [1/4] 检查必要文件
echo [1/4] 检查必要文件...
set "MISSING_CORE=0"

if not exist "frpc.exe" ( 
    echo   [缺失] frpc.exe - 请从 GitHub 下载对应版本
    set "MISSING_CORE=1"
) else (
    echo   [OK] frpc.exe
)

:: WinSW 文件名智能检测与重命名
if not exist "frpc-WinSW.exe" (
    set "FOUND_WINSW=0"
    set "WINSW_ORIGINAL="
    
    if exist "WinSW-x64.exe" (
        set "FOUND_WINSW=1"
        set "WINSW_ORIGINAL=WinSW-x64.exe"
    ) else if exist "WinSW-x86.exe" (
        set "FOUND_WINSW=1"
        set "WINSW_ORIGINAL=WinSW-x86.exe"
    ) else if exist "WinSW-net461.exe" (
        set "FOUND_WINSW=1"
        set "WINSW_ORIGINAL=WinSW-net461.exe"
    ) else if exist "WinSW-netcore31.exe" (
        set "FOUND_WINSW=1"
        set "WINSW_ORIGINAL=WinSW-netcore31.exe"
    ) else if exist "WinSW.exe" (
        set "FOUND_WINSW=1"
        set "WINSW_ORIGINAL=WinSW.exe"
    )
    
    if "!FOUND_WINSW!"=="1" (
        echo   [发现] 检测到 !WINSW_ORIGINAL!，准备重命名...
        ren "!WINSW_ORIGINAL!" "frpc-WinSW.exe" >nul 2>&1
        if !errorlevel! equ 0 (
            echo   [OK] 已重命名为 frpc-WinSW.exe
        ) else (
            echo   [错误] 重命名失败，请手动将 !WINSW_ORIGINAL! 改名为 frpc-WinSW.exe
            set "MISSING_CORE=1"
        )
    ) else (
        echo   [缺失] frpc-WinSW.exe - 请下载 WinSW
        set "MISSING_CORE=1"
    )
) else (
    echo   [OK] frpc-WinSW.exe
)

if not exist "frpc-WinSW.xml" ( 
    echo   [缺失] frpc-WinSW.xml - 服务配置文件
    set "MISSING_CORE=1"
) else (
    echo   [OK] frpc-WinSW.xml
)

if "%MISSING_CORE%"=="1" (
    echo:
    echo [错误] 缺少核心文件，无法继续！
    echo:
    echo 请下载以下组件放到本目录：
    echo   1. FRP 客户端: https://github.com/fatedier/frp/releases 
    echo      （下载 frp_xxx_windows_amd64.zip，解压得 frpc.exe）
    echo   2. WinSW: https://github.com/winsw/winsw/releases 
    echo      （下载 WinSW-x64.exe 等，运行本向导可自动重命名）
    echo:
    pause
    exit
)
echo   [完成] 文件检查通过
echo:

:: [2/4] 检查并配置 frpc.toml
echo [2/4] 检查 FRP 配置文件...

if not exist "frpc.toml" (
    echo   [提示] 未找到 frpc.toml，正在创建模板...
    call :CREATE_CONFIG_TEMPLATE
    if !errorlevel! neq 0 (
        echo   [错误] 创建失败
        pause
        exit
    )
    echo   [OK] 已创建配置模板（UTF-8 无 BOM）
) else (
    echo   [OK] 找到 frpc.toml
)

:: 验证配置内容
:VERIFY_LOOP
call :VERIFY_CONFIG_CONTENT
if "!CONFIG_OK!"=="1" (
    echo   [OK] 配置文件验证通过
    echo:
    :: 安全调用 choice（兼容精简版系统）
    choice /C YN /N /M "   是否需要打开配置文件查看/修改? (Y=是, N=否): " 2>nul
    if !errorlevel! == 1 (
        start /wait notepad frpc.toml
        call :VERIFY_CONFIG_CONTENT
        if "!CONFIG_OK!"=="0" (
            echo   [警告] 修改后配置不完整，请重新编辑...
            goto VERIFY_LOOP
        )
        echo   [OK] 配置验证通过
    )
) else (
    echo   [警告] 配置不完整或包含占位符，请编辑...
    echo   [提示] 必须填写：serverAddr、auth.token、[[proxies]]端口映射
    start /wait notepad frpc.toml
    call :VERIFY_CONFIG_CONTENT
    if "!CONFIG_OK!"=="0" (
        echo   [错误] 配置仍不完整！
        choice /C YN /N /M "   重新编辑(Y)或强制继续(N)? " 2>nul
        if !errorlevel! == 1 goto VERIFY_LOOP
        if !errorlevel! == 2 (
            echo   [警告] 用户选择强制继续，服务可能无法启动
        ) else (
            :: choice 不存在，使用 set /p
            set /p force_continue="   重新编辑(Y)或强制继续(N)? "
            if /i "!force_continue!"=="Y" goto VERIFY_LOOP
            echo   [警告] 用户选择强制继续，服务可能无法启动
        )
    ) else (
        echo   [OK] 配置已完善
    )
)
echo:

:: [3/4] 创建版本记录文件
echo [3/4] 配置版本记录...
if not exist "current_version.txt" (
    echo 0.0.0 > current_version.txt
    echo   [OK] 已创建版本记录（默认0.0.0，建议运行立即更新.bat获取最新）
) else (
    set /p ver=<current_version.txt
    echo   [OK] 版本记录已存在（当前:!ver!）
)
echo:

:: [4/4] 创建必要目录
echo [4/4] 创建必要目录...
if not exist "logs" (
    mkdir logs 2>nul
    if !errorlevel! equ 0 (
        echo   [OK] 创建 logs\ 目录
    ) else (
        echo   [警告] 无法创建 logs\ 目录，请检查权限
    )
) else (
    echo   [OK] logs\ 已存在
)

if not exist "backups" (
    mkdir backups 2>nul
    if !errorlevel! equ 0 (
        echo   [OK] 创建 backups\ 目录
    ) else (
        echo   [警告] 无法创建 backups\ 目录，请检查权限
    )
) else (
    echo   [OK] backups\ 已存在
)
echo:

:: 完成提示
echo =========================================
echo     初始化完成！
echo =========================================
echo:
echo [配置预览]
:: 临时切换 UTF-8 代码页读取配置文件（安全模式）
chcp 65001 >nul 2>&1
if %errorlevel% neq 0 (
    echo   [提示] 无法切换 UTF-8，以下显示可能乱码
)
if exist "frpc.toml" (
    :: 加引号防止特殊字符导致解析错误
    for /f "tokens=*" %%a in ('findstr /r "^serverAddr" frpc.toml 2^>nul') do echo   "%%a"
    for /f "tokens=*" %%a in ('findstr /r "^serverPort" frpc.toml 2^>nul') do echo   "%%a"
    for /f "tokens=*" %%a in ('findstr /r "^auth.token" frpc.toml 2^>nul') do echo   "%%a"
)
:: 确保切回936，即使出错也不影响后续显示
chcp 936 >nul 2>&1
echo:

echo [下一步操作]
echo   1. 运行"设置FRPC为系统服务.bat"
echo   2. 选择 [1] 安装服务  ^<- 首次部署请先执行
echo   3. 选择 [2] 启动服务  ^<- 安装后启动
echo   4. 选择 [9] 管理自动更新任务  ^<- 可选，设置定时检查
echo:
echo [提示] 如需修改配置，编辑 frpc.toml 后重启服务生效
echo:
pause
exit /b

:: =========================================
:: 子程序：创建 UTF-8 无 BOM 配置文件（确保成功版）
:: =========================================
:CREATE_CONFIG_TEMPLATE
:: 直接生成文件（ANSI 编码，确保文件一定存在）
(
echo # FRP 客户端配置文件
echo # 请根据实际情况修改以下配置
echo:
echo serverAddr = "your-server-ip.com"      # 服务器地址，改为实际IP或域名
echo serverPort = 7000                      # 服务器端口，默认7000
echo:
echo # 认证配置
echo auth.method = "token"
echo auth.token = "your-token-here"         # 认证令牌，向管理员获取
echo:
echo # 日志配置
echo log.to = "./logs/frpc.log"
echo log.level = "info"
echo log.maxDays = 3
echo:
echo # 传输加密
echo transport.tls.enable = true
echo:
echo # 端口映射配置，可添加多个[[proxies]]
echo [[proxies]]
echo name = "ssh"                           # 规则名称
echo type = "tcp"                          # 协议类型
echo localIP = "127.0.0.1"                 # 本地地址
echo localPort = 22                        # 本地端口
echo remotePort = 6000                    # 远程端口
echo:
echo # 示例：添加更多映射
echo # [[proxies]]
echo # name = "web"
echo # type = "http"
echo # localIP = "127.0.0.1"
echo # localPort = 8080
echo # customDomains = ["your-domain.com"]
) > frpc.toml

:: 尝试转换为 UTF-8 无 BOM（如果失败也不影响，文件已存在）
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $content=Get-Content 'frpc.toml' -Raw -Encoding Default; [System.IO.File]::WriteAllText('frpc.toml', $content, [System.Text.UTF8Encoding]::new($false)); exit 0 } catch { exit 1 }" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK] 已转换为 UTF-8 无 BOM 编码
) else (
    echo   [提示] 保持 ANSI 编码（FRP 0.52+ 支持读取）
)

:: 只要文件存在就返回成功
if exist "frpc.toml" exit /b 0
exit /b 1

:: =========================================
:: 子程序：验证配置内容
:: =========================================
:VERIFY_CONFIG_CONTENT
set "CONFIG_OK=0"
set "HAS_SERVER=0"
set "HAS_TOKEN=0"
set "HAS_PROXY=0"
set "HAS_PLACEHOLDER=0"

:: 使用 findstr 时添加错误处理，防止文件被占用时脚本中断
findstr /r /c:"serverAddr.*=" frpc.toml >nul 2>&1 && set "HAS_SERVER=1"
findstr /r /c:"auth.token.*=" frpc.toml >nul 2>&1 && set "HAS_TOKEN=1"
findstr /r /c:"\[\[proxies\]\]" frpc.toml >nul 2>&1 && set "HAS_PROXY=1"
findstr /i "your-server-ip\|your-token\|example.com" frpc.toml >nul 2>&1 && set "HAS_PLACEHOLDER=1"

if "!HAS_SERVER!"=="1" if "!HAS_TOKEN!"=="1" if "!HAS_PROXY!"=="1" if "!HAS_PLACEHOLDER!"=="0" (
    set "CONFIG_OK=1"
)
exit /b 0