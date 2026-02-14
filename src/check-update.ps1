# 检查版本并生成标记文件
$currentVersionFile = "$PSScriptRoot\current_version.txt"
$markerFile = "$PSScriptRoot\UPDATE_AVAILABLE.txt"

if (-not (Test-Path $currentVersionFile)) { 
    "0.0.0" | Out-File $currentVersionFile -Force -Encoding ASCII
}

$current = (Get-Content $currentVersionFile).Trim()

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/fatedier/frp/releases/latest" -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 15
    $latest = $release.tag_name -replace '^v',''
    
    if ([version]$latest -gt [version]$current) {
        # 生成标记文件供 BAT 读取
        "$latest|$current" | Out-File $markerFile -Force -Encoding ASCII
        exit 1  # 有更新
    } else {
        if (Test-Path $markerFile) { Remove-Item $markerFile -Force }
        exit 0  # 无更新
    }
} catch {
    exit 2  # 网络错误
}