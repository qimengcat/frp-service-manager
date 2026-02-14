#define MyAppName "FRP 服务管理器"
#define MyAppVersion "1.0"
#define MyAppPublisher "夏慕砚"
#define MyAppURL "https://www.xiamuyan.com/share/software/frp-service-manager.html"

[Setup]
; 基本信息
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 输出设置
DefaultDirName={autopf}\FRP-Service-Manager
DefaultGroupName={#MyAppName}
OutputBaseFilename=FRP-Service-Manager-v{#MyAppVersion}-Setup
OutputDir=.\Output

; 安装选项
PrivilegesRequired=admin
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\设置FRPC为系统服务.bat

; 界面设置
; SetupIconFile=
; WizardImageFile=compiler:WizModernImage-IS.bmp
; WizardSmallImageFile=compiler:WizModernSmallImage-IS.bmp

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
; 桌面图标选项（可多选）
Name: "desktopmanager"; Description: "服务管理器(主程序)"; GroupDescription: "创建桌面快捷方式(可多选):"; Flags: unchecked
Name: "desktopwizard"; Description: "首次配置向导"; GroupDescription: "创建桌面快捷方式(可多选):"; Flags: unchecked  
Name: "desktopupdate"; Description: "检查更新"; GroupDescription: "创建桌面快捷方式(可多选):"; Flags: unchecked
Name: "desktopfolder"; Description: "打开安装文件夹"; GroupDescription: "创建桌面快捷方式(可多选):"; Flags: unchecked

[Files]
; 核心程序文件（必须存在）
Source: "frpc.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "frpc-WinSW.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "frpc-WinSW.xml"; DestDir: "{app}"; Flags: ignoreversion

; 批处理脚本
Source: "首次使用向导.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "设置FRPC为系统服务.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "检查更新.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "立即更新.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "卸载所有配置.bat"; DestDir: "{app}"; Flags: ignoreversion

; PowerShell 脚本
Source: "auto-update-frp.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "check-update.ps1"; DestDir: "{app}"; Flags: ignoreversion

; 配置文件（如果存在则复制，不存在则跳过）
Source: "frpc.toml"; DestDir: "{app}"; Flags: ignoreversion onlyifdoesntexist
Source: "current_version.txt"; DestDir: "{app}"; Flags: ignoreversion onlyifdoesntexist

; 创建空目录
[Dirs]
Name: "{app}\backups"
Name: "{app}\logs"

[Icons]
; 开始菜单（始终创建）
Name: "{group}\{#MyAppName}\管理器"; Filename: "{app}\设置FRPC为系统服务.bat"
Name: "{group}\{#MyAppName}\首次配置向导"; Filename: "{app}\首次使用向导.bat"
Name: "{group}\{#MyAppName}\检查更新"; Filename: "{app}\检查更新.bat"
Name: "{group}\{#MyAppName}\立即更新"; Filename: "{app}\立即更新.bat"
Name: "{group}\{#MyAppName}\完全卸载"; Filename: "{app}\卸载所有配置.bat"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; 桌面快捷方式（根据用户勾选创建）
Name: "{commondesktop}\{#MyAppName} 管理器"; Filename: "{app}\设置FRPC为系统服务.bat"; Tasks: desktopmanager
Name: "{commondesktop}\{#MyAppName} 首次配置"; Filename: "{app}\首次使用向导.bat"; Tasks: desktopwizard
Name: "{commondesktop}\{#MyAppName} 检查更新"; Filename: "{app}\检查更新.bat"; Tasks: desktopupdate

; 【修复】打开安装目录 - 方法1：直接指向文件夹（推荐）
Name: "{commondesktop}\{#MyAppName} 安装目录"; Filename: "{app}"; Tasks: desktopfolder; IconFilename: "{win}\explorer.exe"

; 或者方法2：显式调用 explorer（如果方法1不行，取消注释下面这行，注释掉上面那行）
; Name: "{commondesktop}\{#MyAppName} 安装目录"; Filename: "{win}\explorer.exe"; Parameters: "/e,""{app}"""; Tasks: desktopfolder

[Run]
; 【修复】安装完成后打开安装目录 - 使用 shellexec 打开文件夹路径
Filename: "{app}"; Description: "打开安装目录"; Flags: nowait postinstall skipifsilent shellexec

[UninstallDelete]
; 卸载时删除日志和临时文件，但保留backups（用户数据）
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\temp_update"
Type: files; Name: "{app}\UPDATE_AVAILABLE.txt"
Type: files; Name: "{app}\frp_v*_windows_amd64.zip"

[Registry]
; 可选：写入版本信息到注册表（方便后续检查）
Root: HKLM; Subkey: "Software\FRP-Service-Manager"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\FRP-Service-Manager"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"

[Code]
// 自定义卸载提示
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // 卸载完成后提示用户手动删除 backups 目录（如果有数据）
    if DirExists(ExpandConstant('{app}\backups')) then
    begin
      if MsgBox('检测到 backups 目录可能包含旧版本备份文件。' + #13#10 + 
                '是否保留该目录？（选择"否"将删除所有备份）', 
                mbConfirmation, MB_YESNO) = IDNO then
      begin
        DelTree(ExpandConstant('{app}\backups'), True, True, True);
      end;
    end;
  end;
end;