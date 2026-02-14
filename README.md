# frp-service-manager
frpc，部署到Windows系统服务，轻松实现内网穿透！ 

================================================================================
FRP 内网穿透服务 - 完整目录结构说明文档
版本: 1.0
适用环境: Windows 10/11/Server 2016+
最后更新: 2026-02-12
================================================================================

【目录结构总览】

D:\frp\                              [主目录 - 建议放在非系统盘，避免权限问题]
├── frpc.exe                          [核心程序 - FRP客户端主文件]
├── frpc.toml                         [核心配置 - FRP连接参数与端口映射 默认UTF-8编码]
│
├── frpc-WinSW.exe                    [服务外壳 - WinSW服务包装器]
├── frpc-WinSW.xml                    [服务配置 - 系统服务参数定义]
│
├── current_version.txt               [版本标记 - 当前安装的FRP版本号]
│
├── 设置FRPC为系统服务.bat            [管理工具 - 交互式服务管理菜单]
├── 检查更新.bat                      [维护工具 - 手动检查版本更新]
├── 立即更新.bat                      [维护工具 - 强制立即更新]

├── 首次使用向导.bat              [维护工具 - 首次使用向导]

├── 卸载所有配置.bat              [维护工具 - 卸载现有所有配置]

│
├── check-update.ps1                  [后台脚本 - 轻量级版本检查]
├── auto-update-frp.ps1               [后台脚本 - 全自动更新逻辑]
│
├── frp_v0.67.0_windows_amd64.zip     [安装包备份 - GitHub原始包(保留3个)]
│
├── backups\                          [备份目录 - 旧版本exe保留]
│   ├── frpc_v0.61.0_20240212_090000.exe
│   └── frpc_v0.60.0_20240205_143022.exe
│
└── logs\                             [日志目录 - 运行日志与更新记录]


================================================================================
【核心程序文件 - 必需】
================================================================================

1. frpc.exe
   类型: 可执行程序 (ELF/PE)
   来源: GitHub releases (fatedier/frp)
   作用: FRP客户端主程序，负责与FRP服务器建立加密连接，实现内网穿透
   配置: 通过 frpc.toml 读取连接参数
   注意: 
     - 更新时此文件会被替换，建议保留backups目录备份
     - 文件本身不含版本信息(Windows属性中显示0.0.0.0)，依赖current_version.txt记录版本

2. frpc.toml
   类型: 文本配置文件 (TOML格式)
   来源: 用户手动编辑 或 服务器提供商提供
   作用: 定义FRP服务器地址、认证token、本地端口映射规则等
   示例内容:
     serverAddr = "xxx.xxx.xxx.xxx"
     serverPort = 7000
     auth.token = "your_token_here"
   
     [[proxies]]
     name = "ssh"
     type = "tcp"
     localIP = "127.0.0.1"
     localPort = 22
     remotePort = 6000
   注意:
     - 修改此文件后需重启服务生效 (管理菜单选4或先3后2)
     - 建议定期备份，避免误删导致连接信息丢失

3. frpc-WinSW.exe
   类型: 可执行程序 (Windows服务包装器)
   来源: https://github.com/winsw/winsw/releases
   作用: 将普通exe程序包装为Windows系统服务，实现:
     - 开机自动启动(无需登录用户)
     - 进程守护(崩溃自动重启)
     - 日志管理(滚动日志)
   注意:
     - 必须与 frpc-WinSW.xml 同名且同目录
     - 安装服务后会写入系统注册表，勿随意移动位置
     - 卸载服务前必须先停止服务

4. frpc-WinSW.xml
   类型: XML配置文件
   来源: 用户配置(基于WinSW文档)
   作用: 定义服务名称、启动参数、日志策略、故障恢复等
   关键配置项:
     - <id>frpc</id> : 服务唯一标识，影响sc query和net start命令中的名称
     - <startmode>Automatic</startmode> : 开机自启
     - <delayedAutoStart/> : 延迟启动(等网络就绪)
     - <onfailure action="restart"/> : 崩溃自动重启
   注意:
     - 修改XML后需卸载重装服务生效(或重启计算机)
     - 服务名(id)必须与批处理脚本中的SERVICE_NAME变量一致


================================================================================
【版本管理文件 - 自动更新必需】
================================================================================

5. current_version.txt
   类型: 纯文本文件
   来源: 用户手动创建(首次部署时)
   作用: 记录当前安装的FRP版本号，用于与GitHub最新版比对
   内容格式: 纯数字版本号，如 0.61.0 或 0.67.0
   创建方法:
     记事本打开，写入当前版本号(如0.61.0)，保存为current_version.txt
   注意:
     - 此文件缺失会导致自动更新脚本认为当前版本为0.0.0，触发不必要的更新
     - 每次成功更新后，脚本会自动覆盖此文件为最新版本号

6. frp_v[版本号]_windows_amd64.zip
   类型: 压缩文件 (ZIP)
   来源: 自动从GitHub releases下载
   作用: 保留GitHub原始安装包，用于:
     - 手动回滚(解压后替换frpc.exe)
     - 查看历史版本变更
     - 离线环境分发
   命名示例: frp_v0.67.0_windows_amd64.zip
   清理策略: 自动保留最近3个，更早的自动删除(可在auto-update-frp.ps1中修改)
   位置: 与frpc.exe同级目录(非backups子目录)

7. UPDATE_AVAILABLE.txt
   类型: 临时标记文件
   来源: check-update.ps1自动生成
   作用: 标记发现新版本的状态，供批处理脚本读取显示
   内容示例:
     新版本: 0.67.0
     当前: 0.61.0
     发布时间: 2024-02-10T08:30:00Z
     下载页: https://github.com/fatedier/frp/releases/tag/v0.67.0
   生命周期: 下次成功更新后自动删除，或手动删除


================================================================================
【管理工具脚本 - 推荐】
================================================================================

8. 设置FRPC为系统服务.bat
   类型: Windows批处理脚本 (ANSI编码)
   来源: 本说明文档提供
   作用: 交互式服务管理菜单，功能包括:
     [1] 安装服务 - 调用frpc-WinSW.exe install
     [2] 启动服务 - 调用net start frpc
     [3] 停止服务 - 调用net stop frpc
     [4] 重启服务 - 先stop后start(用于配置文件热重载)
     [5] 查看详细状态 - 显示sc query结果和进程列表
     [6] 打开服务管理器 - 启动services.msc
     [7] 检查FRP更新 - 调用"检查更新.bat"
     [8] 删除服务 - 卸载服务(需输入YES确认)
     [0] 退出
   特性:
     - 自动请求管理员权限(UAC提权)
     - 自动从XML读取服务名(适配frpc-WinSW.xml中的<id>)
     - 实时状态显示(菜单显示当前运行/停止状态)
   使用: 双击运行，按数字键选择功能

9. 检查更新.bat
   类型: Windows批处理脚本
   来源: 本说明文档提供
   作用: 手动触发版本检查，逻辑:
     - 调用check-update.ps1查询GitHub API
     - 无更新: 显示"当前已是最新版本"
     - 有更新: 弹窗提示，用户可选择"是"立即更新或"否"稍后处理
   特点: 非静默模式，适合日常手动检查
   依赖: 需同目录存在check-update.ps1

10. 立即更新.bat
    类型: Windows批处理脚本
    来源: 本说明文档提供
    作用: 跳过确认对话框，直接执行全自动更新流程
    逻辑: 调用auto-update-frp.ps1执行:
      检测版本 → 下载ZIP → 备份旧版 → 停止服务 → 替换exe → 启动服务 → 清理
    风险: 强制更新，请确保当前无重要连接在进行
    适用: 深夜维护窗口或确定要升级时

11. check-update.ps1
    类型: PowerShell脚本
    来源: 本说明文档提供
    作用: 轻量级检查脚本，仅查询版本不执行文件操作
    流程:
      读取current_version.txt → 查询GitHub API → 比较版本号
      → 无更新: 静默退出
      → 有更新: 生成UPDATE_AVAILABLE.txt + 弹窗提示
    特点: 执行快(仅API查询)，不阻塞，适合计划任务频繁调用

12. auto-update-frp.ps1
    类型: PowerShell脚本
    来源: 本说明文档提供
    作用: 全自动更新引擎，完整流程:
      1. 读取current_version.txt获取本地版本
      2. 调用GitHub API获取latest release
      3. 比较版本号(new > current则继续)
      4. 模糊匹配下载 windows_amd64.zip
      5. 解压到临时目录temp_update\
      6. 备份当前frpc.exe到backups\ (带时间戳)
      7. 停止WinSW服务 (确保frpc.exe进程结束)
      8. 替换frpc.exe (原子操作: 先重命名旧文件再复制新文件)
      9. 保留原始ZIP到主目录(保留3个旧版本)
      10. 启动服务并验证状态
      11. 更新current_version.txt
      12. 清理临时文件和过期备份
    容错:
      - 下载失败: 保留旧版，不停止服务
      - 替换失败: 自动从backup回滚
      - 启动失败: 回滚并报警
        参数:
        -Silent: 无弹窗(用于计划任务)
        -Force: 强制更新(无视版本比较)


================================================================================
【自动生成目录】
================================================================================

13. backups\ 目录
    创建时机: 首次执行auto-update-frp.ps1时自动创建
    内容: 旧版本frpc.exe备份，命名格式:
      frpc_v[版本号]_[年月日]_[时分秒].exe
      示例: frpc_v0.61.0_20240212_090000.exe
    保留策略: 默认保留最近5个，更早的自动删除
    用途: 
      - 新版异常时手动回滚(停止服务后复制回frpc.exe)
      - 版本审计追踪
    清理: 可手动删除，但建议保留至少1个稳定版本

14. logs\ 目录
    创建时机: 
      - WinSW首次启动时自动创建(用于frpc.out.log等)
      - auto-update-frp.ps1首次运行时创建(用于frp-update.log)
    内容:
        frpc.out.log: FRP客户端标准输出(连接日志)
        frpc.err.log: FRP客户端错误输出
        frp-rolling-*.log: WinSW服务管理日志(启动/停止记录)
        frp-update.log: 自动更新操作记录(时间戳、版本变化、错误信息)
    管理:
      - 按WinSW配置自动滚动(按大小10MB或按天)
      - 自动压缩5天前的日志为zip
      - 定期手动清理可释放空间


================================================================================
【使用流程指南】
================================================================================

【首次部署步骤】
1. 创建目录 D:\frp\ (建议非C盘)
2. 放入 frpc.exe, frpc.toml, frpc-WinSW.exe, frpc-WinSW.xml
3. 记事本创建 current_version.txt，写入当前版本号(如0.61.0)
4. 放入管理脚本(4个bat和2个ps1)
5. 双击"设置FRPC为系统服务.bat"
6. 按1安装服务，按2启动服务
7. 按5查看状态，确认显示[运行中]

【配置文件修改流程】
1. 编辑 frpc.toml (如修改远程端口)
2. 双击"设置FRPC为系统服务.bat"
3. 按4重启服务(或先3停止再2启动)
4. 按5查看状态确认已应用

【版本更新流程】
方式A - 手动检查:
  1. 双击"检查更新.bat"
  2. 如有更新，弹窗点击"是"
  3. 等待自动完成(约30秒-2分钟，视网络而定)
  4. 查看日志确认成功

方式B - 自动提醒(需安装计划任务):
  1. 以管理员运行命令安装计划任务:
     schtasks /create /tn "FRP更新提醒" /tr "D:\frp\检查更新.bat" /sc daily /st 09:00 /ru SYSTEM
  2. 每天9:00自动检查，有更新弹窗提示
  3. 用户点击"是"执行更新

【故障恢复】
场景: 更新后服务无法启动
  1. 进入backups\目录，找到上次成功版本的exe
  2. 停止服务(管理菜单选3)
  3. 复制 backups\frpc_v[旧版本]_xxxx.exe 覆盖 frpc.exe
  4. 编辑current_version.txt改回旧版本号
  5. 启动服务(管理菜单选2)


================================================================================
【配置文件示例】
================================================================================

【frpc-WinSW.xml 推荐配置】
<?xml version="1.0" encoding="UTF-8"?>
<service>
    <id>frpc</id>
    <name>frpc</name>
    <description>frp客户端，提供内网穿透服务</description>
    
    <serviceaccount>
        <domain>NT AUTHORITY</domain>
        <user>LocalService</user>
        <allowservicelogon>true</allowservicelogon>
    </serviceaccount>
    
    <env name="HOME" value="%BASE%"/>
    <executable>%BASE%\frpc.exe</executable>
    <arguments>-c .\frpc.toml</arguments>
    <workingdirectory>%BASE%</workingdirectory>
    
    <startmode>Automatic</startmode>
    <delayedAutoStart/>
    <depend>Tcpip</depend>
    <depend>NlaSvc</depend>
    
    <onfailure action="restart" delay="10 sec"/>
    <onfailure action="restart" delay="20 sec"/>
    <onfailure action="restart" delay="60 sec"/>
    <resetfailure>1 hour</resetfailure>
    
    <stoptimeout>30 sec</stoptimeout>
    
    <logpath>%BASE%\logs</logpath>
    <log mode="roll-by-size-time">
        <sizeThreshold>10240</sizeThreshold>
        <pattern>yyyyMMdd</pattern>
        <autoRollAtTime>00:00:00</autoRollAtTime>
        <zipOlderThanNumDays>5</zipOlderThanNumDays>
    </log>
</service>


================================================================================
【常见问题 FAQ】
================================================================================

Q1: 为什么有两个进程(frpc-WinSW.exe和frpc.exe)?
A: 这是WinSW的正常工作模式。WinSW作为父进程(服务宿主)运行，负责守护子进程frpc.exe。
   如果frpc崩溃，WinSW会自动重启它。停止服务时，WinSW会优雅地终止frpc。

Q2: current_version.txt可以删除吗?
A: 不可以。删除后自动更新脚本会认为当前是0.0.0版本，导致每次检查都提示"发现新版本"。

Q3: 如何完全卸载FRP服务?
A: 1. 运行管理菜单选8(删除服务)
   2. 确认服务已从services.msc消失
   3. 删除整个D:\frp\目录即可

Q4: 更新失败如何回滚?
A: 进入backups\目录，找到更新前的exe文件(看时间戳)，手动复制替换frpc.exe，
   修改current_version.txt为旧版本号，重启服务。

Q5: 日志文件太大怎么办?
A: WinSW已配置自动滚动(log mode="roll-by-size-time")，超过10MB或每天0点自动切分，
   5天前的自动压缩。如需手动清理，直接删除logs\目录内旧文件即可。


================================================================================
【安全建议】
================================================================================

1. 目录权限: 建议将D:\frp\目录权限设置为Administrators和SYSTEM完全控制，其他用户只读
2. 配置文件: frpc.toml中包含服务器token，应设置为只有SYSTEM和管理员可读
3. 防火墙: frpc.exe需要出站规则访问FRP服务器端口(默认7000)，建议限制IP范围
4. 更新源: auto-update-frp.ps1默认从GitHub下载，如需内网环境使用，请修改$apiUrl为内部镜像


================================================================================
文档结束
================================================================================
