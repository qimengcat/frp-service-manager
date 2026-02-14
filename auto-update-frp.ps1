# FRP 全自动更新脚本
param(
    [switch]$Silent,
    [switch]$Force
)

# ==================== 配置区 ====================
$serviceName = "frpc"    
# 如果 frpc-WinSW.xml 中的 <id> 不是 frpc，请修改上面

$currentVersionFile = "$PSScriptRoot\current_version.txt"
$frpcPath = "$PSScriptRoot\frpc.exe"
$backupDir = "$PSScriptRoot\backups"
$tempDir = "$PSScriptRoot\temp_update"
$logFile = "$PSScriptRoot\logs\frp-update.log"
# ===============================================

# 确保日志目录存在
if (-not (Test-Path "$PSScriptRoot\logs")) { 
    New-Item -ItemType Directory -Path "$PSScriptRoot\logs" -Force | Out-Null 
}

# 读取当前版本
if (-not (Test-Path $currentVersionFile)) { "0.0.0" | Out-File $currentVersionFile -Force -Encoding ASCII }
$currentVersion = (Get-Content $currentVersionFile -Raw).Trim()

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
    if (-not $Silent) { Write-Host $logEntry }
}

function Show-Notify {
    param($Title, $Message, $Icon = "Info")
    Write-Log "$Title - $Message"
    
    if (-not $Silent) {
        try {
            $wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
            $iconCode = switch ($Icon) {
                "Error"   { 16 }
                "Warning" { 48 }
                default   { 64 }
            }
            $wshell.Popup($Message, 0, $Title, $iconCode) | Out-Null
        } catch {
            Write-Host "[$Title] $Message" -ForegroundColor Yellow
        }
    }
}

try {
    Write-Log "========== FRP 更新启动 =========="
    Write-Log "当前版本: $currentVersion | 服务名: $serviceName"
    
    # 检查管理员权限
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "请以管理员身份运行"
    }

    # 获取 GitHub 最新版本
    $apiUrl = "https://api.github.com/repos/fatedier/frp/releases/latest"
    $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
    
    Write-Log "正在查询 GitHub..."
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30
    
    $latestVersion = $release.tag_name -replace '^v', ''
    $publishDate = $release.published_at
    Write-Log "远程版本: $latestVersion (发布于 $publishDate)"
    
    # 版本比较
    if (-not $Force -and ([version]$latestVersion -le [version]$currentVersion)) {
        Write-Log "当前已是最新版本"
        Show-Notify -Title "无需更新" -Message "当前 $currentVersion 已是最新" -Icon "Info"
        exit 0
    }

    # 确认更新
    if (-not $Silent) {
        $wshell = New-Object -ComObject Wscript.Shell
        $confirm = $wshell.Popup("发现新版本: $latestVersion`n当前: $currentVersion`n`n是否立即更新？", 0, "FRP 更新确认", 32 + 1)
        
        if ($confirm -ne 1) {
            Write-Log "用户取消更新"
            exit 0
        }
    }

    # 下载
    $asset = $release.assets | Where-Object { $_.name -like "*windows_amd64.zip" } | Select-Object -First 1
    if (-not $asset) { throw "未找到 Windows amd64 版本" }
    
    $zipPath = "$tempDir\frp.zip"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    Write-Log "正在下载: $($asset.name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -TimeoutSec 300 -UseBasicParsing
    
    # 解压
    Write-Log "正在解压..."
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    $extractedFrpc = Get-ChildItem -Path $tempDir -Recurse -Filter "frpc.exe" | Select-Object -First 1
    if (-not $extractedFrpc) { throw "解压后未找到 frpc.exe" }

    # 备份
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupName = "frpc_v${currentVersion}_$timestamp.exe"
    $backupPath = Join-Path $backupDir $backupName
    Copy-Item $frpcPath $backupPath -Force
    Write-Log "已备份: $backupName"

    # 停止服务
    Write-Log "正在停止服务..."
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -eq "Running") {
        Stop-Service -Name $serviceName -Force
        Start-Sleep -Seconds 2
        Get-Process -Name "frpc" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # 替换文件
    Write-Log "正在替换 frpc.exe..."
    Rename-Item $frpcPath "$frpcPath.old" -Force -ErrorAction SilentlyContinue
    Copy-Item $extractedFrpc.FullName $frpcPath -Force

    # 保留原始压缩包
    $keepZipName = "frp_v${latestVersion}_windows_amd64.zip"
    Copy-Item $zipPath (Join-Path $PSScriptRoot $keepZipName) -Force
    Get-ChildItem -Path $PSScriptRoot -Filter "frp_v*_windows_amd64.zip" | 
        Sort-Object CreationTime -Descending | 
        Select-Object -Skip 3 | 
        Remove-Item -Force -ErrorAction SilentlyContinue

    # 启动服务
    Write-Log "正在启动服务..."
    Start-Service -Name $serviceName -ErrorAction Stop
    Start-Sleep -Seconds 3
    
    if ((Get-Service -Name $serviceName).Status -ne "Running") {
        throw "服务启动失败"
    }
    
    # 更新版本记录（无BOM）
    $latestVersion | Out-File $currentVersionFile -Force -Encoding ASCII -NoNewline
    
    # 清理
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$frpcPath.old" -Force -ErrorAction SilentlyContinue
    
    # 清理旧备份（保留5个）
    Get-ChildItem $backupDir -Filter "frpc_v*.exe" | 
        Sort-Object CreationTime -Descending | 
        Select-Object -Skip 5 | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Log "更新成功: $currentVersion -> $latestVersion"
    Show-Notify -Title "更新成功" -Message "已更新到 $latestVersion" -Icon "Info"
    exit 0

} catch {
    $errMsg = $_.Exception.Message
    Write-Log $errMsg -Level "ERROR"
    Show-Notify -Title "更新失败" -Message $errMsg -Icon "Error"
    
    # 回滚
    if (Test-Path $backupPath) {
        Write-Log "尝试回滚..."
        Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Copy-Item $backupPath $frpcPath -Force
        Start-Service $serviceName -ErrorAction SilentlyContinue
        Show-Notify -Title "已回滚" -Message "恢复到 $currentVersion" -Icon "Warning"
    }
    exit 1
}