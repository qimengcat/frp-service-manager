<h3 align="center">Frp-Service-Manager</h3>

  <p align="center">
    🎉 Windows平台管理frp客户端，轻松部署到Windows系统服务，轻松实现内网穿透！
    <br />
    支持所有frp版本 / 开机随系统服务自启 / 可视化配置 / 免费开源
  </p>

## TODO

- [x] 开机随系统服务自启动
- [x] 一键生成默认frpc.toml
- [x] 通过镜像站自动下载/更新frp
- [x] 一键卸载配置
- [x] 自选生成桌面快捷方式


## 里程碑

- 2026-02-14: 发布v1.0版本

## 安装后目录结构总览

- D:\\FRP-Service-Manager\ 【安装根目录】

  - backups\ 【存储历史frpc.exe】
  - logs\ 【运行日志】
  - frpc.exe 【FRP客户端主文件，默认：v0.67.0】
  - current_version.txt 【存放FRPC版本信息，默认：v0.67.0】
  - frpc.toml 【FRP连接参数与端口映射 默认UTF-8编码】
  - frpc-WinSW.exe 【WinSW服务包装器，默认：v2.12.0】
  - frpc-WinSW.xml 【WinSW服务配置】
  - check-update.ps1 【轻量级frpc版本检查】
  - auto-update-frp.ps1 【全自动更新frpc版本】

  - 首次使用向导.bat 【首次使用向导】
  - 设置FRPC为系统服务.bat 【交互式服务管理菜单】
  - 检查更新.bat 【手动检查frpc版本更新】
  - 立即更新.bat 【强制立即更新frpc版本】
  - 卸载所有配置.bat 【卸载现有所有配置】

## 演示

![Frp-Service-Manager01](https://github.com/qimengcat/frp-service-manager/blob/main/screenshot/Frp-Service-Manager01.png?raw=true)

![Frp-Service-Manager02](https://github.com/qimengcat/frp-service-manager/blob/main/screenshot/Frp-Service-Manager02.png?raw=true)

![Frp-Service-Manager03](https://github.com/qimengcat/frp-service-manager/blob/main/screenshot/Frp-Service-Manager03.png?raw=true)

![Frp-Service-Manager04](https://github.com/qimengcat/frp-service-manager/blob/main/screenshot/Frp-Service-Manager04.png?raw=true)

![Frp-Service-Manager05](https://github.com/qimengcat/frp-service-manager/blob/main/screenshot/Frp-Service-Manager05.png?raw=true)

## 文件说明

### 【核心程序文件 - 必需】

1. #### frpc.exe

   类型: 可执行程序 (ELF/PE)
   来源: [GitHub releases (fatedier/frp)](https://github.com/fatedier/frp)
   作用: FRP客户端主程序，负责与FRP服务器建立加密连接，实现内网穿透
   配置: 通过 frpc.toml 读取连接参 数
   注意: 

     - 更新时此文件会被替换，建议保留backups目录备份
     - 文件本身不含版本信息(Windows属性中显示0.0.0.0)，依赖current_version.txt记录版本
     - 默认版本：v0.67.0

2. #### frpc.toml

   类型: 文本配置文件 (TOML格式，默认UTF-8编码)
   来源: 用户手动编辑 或 服务器提供商提供
   作用: 定义FRP服务器地址、认证token、本地端口映射规则等

     - 修改此文件后需重启服务生效

     - 建议定期备份，避免误删导致连接信息丢失

     - 运行首次使用向导.bat后校验是否存在该文件，没有会自动生成，生成内容如下：

       ```
       # FRP 客户端配置文件
       # 请根据实际情况修改以下配置
       
       serverAddr = "47.108.208.91"      # 服务器地址，改为实际IP或域名
       serverPort = 7000                      # 服务器端口，默认7000
       
       # 认证配置
       auth.method = "token"
       auth.token = "QImeng9420"         # 认证令牌，向管理员获取
       
       # 日志配置
       log.to = "./logs/frpc.log"
       log.level = "info"
       log.maxDays = 3
       
       # 传输加密
       transport.tls.enable = true
       
       # 端口映射配置，可添加多个[[proxies]]
       [[proxies]]
       name = "dxfsheji-tcp"
       type = "tcp"
       localIP = "127.0.0.1"
       localPort = 3389
       remotePort = 6010
       
       [[proxies]]
       name = "ssh"                           # 规则名称
       type = "tcp"                          # 协议类型
       localIP = "127.0.0.1"                 # 本地地址
       localPort = 22                        # 本地端口
       remotePort = 6000                    # 远程端口
       
       # 示例：添加更多映射
       # [[proxies]]
       # name = "web"
       # type = "http"
       # localIP = "127.0.0.1"
       # localPort = 8080
       # customDomains = ["your-domain.com"]
       
       ```

3. #### frpc-WinSW.exe

   类型: 可执行程序 (Windows服务包装器)
   来源: [GitHub releases (winsw/winsw)](https://github.com/winsw/winsw)
   作用: 将普通exe程序包装为Windows系统服务，实现:

     - 开机自动启动(无需登录用户)
     - 进程守护(崩溃自动重启)
     - 日志管理(滚动日志)
     - 必须与 frpc-WinSW.xml 同名且同目录
     - 安装服务后会写入系统注册表，勿随意移动位置
     - 卸载服务前必须先停止服务
     - 默认版本：v2.12.0

4. #### frpc-WinSW.xml

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

5. #### current_version.txt

   类型: 纯文本文件
   来源: 用户手动创建(首次部署时)
   作用: 记录当前安装的FRP版本号，用于与GitHub最新版比对
   内容格式: 纯数字版本号，默认为 0.67.0
   创建方法:
     记事本打开，写入当前版本号(如0.67.0)，保存为current_version.txt
   注意:

     - 此文件缺失会导致自动更新脚本认为当前版本为0.0.0，触发不必要的更新

     - 每次成功更新后，脚本会自动覆盖此文件为最新版本号

     - 默认内容：

       ```
       0.67.0
       ```

6. #### backups\ 目录

   创建时机: 首次执行auto-update-frp.ps1时自动创建
   内容: 旧版本frpc.exe备份，命名格式:
     frpc_v[版本号]_[年月日]_[时分秒].exe
     示例: frpc_v0.67.0_20260214_090000.exe
   保留策略: 默认保留最近5个，更早的自动删除
   用途: 

     - 新版异常时手动回滚(停止服务后复制回frpc.exe)
     - 版本审计追踪
       清理: 可手动删除，但建议保留至少1个稳定版本

7. #### logs\ 目录

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

## License

[MIT](LICENSE)
