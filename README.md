# 余烬远征 · Godot / Go 游戏框架原型

以放置卡牌的五人编队、自动战斗、养成与挂机循环为参考，用原创角色、地图文案和矢量图做可运行原型。包含 **6 名英雄、6 个关卡、3 件装备、6 个技能**，支持简体中文、繁体中文、英文。

Godot 负责显示，Go 负责权威业务；单机 DLL 和 WebSocket 服务器复用同一个 Go Runtime。在线玩法通过长连接传输 protobuf 二进制消息，账号验证可使用 HTTP。首次进入同步全量状态，后续按脏模块和装备通知增量同步；存档使用独立的 protobuf 协议。所有页面布局静态保存在 `.tscn`，所有策划表通过本机已有的 **excel2pb 项目**导出。

## 启动

本机已经构建完成，可直接执行：

```powershell
# 启动单机原型
./tools/run.ps1

# 另开终端启动开发服务器，然后在游戏右上角选择“切换在线冒险”
./tools/run.ps1 -Server
```

或用 **Godot 4.7.1** 打开 `client/project.godot`，按 F5。语言在顶部下拉框中切换。两个模式各有独立进度，切换不会复制存档。

在线地址配置为 `client/project.godot` 中的 `game/server_url="ws://127.0.0.1:18080/ws"`，子协议为 `gameframe.v2`。`RemoteBackend` 保持连接、收发二进制消息并处理断线重连；服务器启动后可自动恢复。未确认命令使用原 ID 重发，随后同步最新状态。原 `POST /command` 已移除。当前仍使用开发 token 校验握手，尚未实现正式账号登录服务；接入后可通过 HTTP 获取会话凭据，再用于 WebSocket 连接认证。

首次游玩建议：开始战斗 → 英雄页面升级 → 装备页面选择英雄并穿戴 → 阵容页面选择位置和英雄并保存 → 继续推进战役。旅途补给由 Go 计时，离线累计最多 12 小时，界面每 5 秒增量刷新挂机信息；版本不一致时恢复全量状态。

## Docker Compose 服务器

```powershell
python tools/init_docker.py
docker compose up -d --build --wait
python tools/configure_docker_client.py
```

默认 WebSocket 为 `ws://127.0.0.1:18080/ws`，存档保存在独立命名卷。配置脚本将实际端口和令牌写入已被 Git 忽略的 `client/override.cfg`；重启客户端后即可切换在线冒险。修改端口或轮换令牌后重新运行该脚本。客户端配置及备份、更新、测试步骤见 [Docker 部署](docs/Docker部署.md)。镜像只包含 Linux Go 服务器，使用非 root 用户、健康检查和只读根文件系统。当前文件存储按单实例运行。

## 在新机器构建

当前已验证：**Windows x64、Godot 4.7.1、Go 1.26.4、MinGW-w64 GCC 14.2**。需要 Python、protoc、protoc-gen-go 在 PATH 中。MinGW 建议安装在纯英文路径，否则其链接器可能无法识别路径。

1. 将 `tools.local.example.json` 复制为 `tools.local.json`，填写 Godot、MinGW 和 excel2pb 源码位置。本机配置已填写，且被 git 忽略。
2. excel2pb 使用 `tools/excel2pb.lock.json` 中的固定提交：`7a45c37f03558147cc8cf0cf5500bba61da47e02`。构建脚本只读取并编译现有仓库，不会替你切换它的分支。
3. 安装生成依赖并构建：

```powershell
python -m pip install -r tools/requirements.txt
python -m pip install -r tools/requirements-tests.txt
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.11
./tools/build.ps1 -Test
```

构建顺序：编译 excel2pb → Excel 导出 → 格式化工作簿 → 业务/存档 proto 生成 → Go 权威、存储与 WebSocket 测试 → Go DLL / server → GDExtension → Godot 导入 → DLL/WebSocket/状态同步/界面集成测试。测试使用独立临时存档和临时端口。

`./tools/build.ps1 -Test -Headless` 可用于无显示环境；`-SkipTables` 只适用于 Excel 未变化的情况。重新构建 DLL 前先退出正在运行的本原型。

## 目录

```text
game-frame/
├─ client/                         Godot 客户端
│  ├─ project.godot                引擎设置、开发连接配置
│  ├─ ui/
│  │  ├─ main.tscn                 四个页面、固定卡片和槽位的静态布局
│  │  ├─ components/              静态场景中引用的英雄卡和战斗角色
│  │  ├─ adventure_view.gd        节点展示、信号、战报动画
│  │  ├─ adventure_presenter.gd   页面选择、翻译和展示数据
│  │  └─ theme.tres               字体、颜色、边框和控件样式
│  ├─ scripts/
│  │  ├─ bootstrap.gd             依赖组装和生命周期
│  │  ├─ localization.gd          注册 excel2pb 动态翻译
│  │  ├─ services/                语义查询，隐藏生成表结构
│  │  ├─ transport/               Session、protobuf 编解码、DLL / WebSocket 适配
│  │  └─ state/                   模块状态、装备通知合并与版本检查
│  ├─ localization/ui.*.po        Godot 固定 UI 文案和格式模板
│  ├─ config/{generated,data}/    excel2pb 生成的读取器和 .bytes
│  ├─ protobuf/                   生成的 GDScript protobuf 和运行时
│  ├─ addons/game_bridge/         GDExtension 配置及构建出的 DLL
│  ├─ assets/                     原创 SVG 原型素材
│  └─ tests/smoke.gd              实际场景交互、语言、模式切换测试
├─ game/                          单独 Go module：gameframe
│  ├─ cmd/sharedlib/              C ABI：GameCall / GameFree
│  ├─ cmd/server/                 WebSocket 开发服务器、HTTP 健康检查
│  ├─ internal/domain/            状态、命令、快照、战斗事件
│  ├─ internal/application/       权威规则、脏模块同步、SaveToDB/存档迁移
│  ├─ internal/protocol/          生成的共享业务 protobuf
│  ├─ internal/persistence/       生成的服务端私有存档 protobuf
│  ├─ internal/ports/             存储、时钟接口
│  ├─ internal/adapters/storage/  文件存档、真实时钟
│  ├─ internal/adapters/wsbackend/ WebSocket 认证、消息循环、心跳
│  ├─ internal/generated/         excel2pb 生成的 Go protobuf
│  ├─ internal/generatedloaders/  excel2pb 模板生成的配置读取器
│  └─ data/                      嵌入 DLL / server 的 .data
├─ bridge/godot/                 薄 C 桥接，无游戏规则
├─ table/
│  ├─ xlsx/                      Excel 源文件，策划修改入口
│  └─ excel2pb.yaml               双端生成与 I18N 配置
├─ contracts/
│  ├─ shared/
│  │  ├─ Command.proto          业务命令入口
│  │  ├─ GameResponse.proto     组合状态、通知与战报的响应
│  │  ├─ gamestate/             StateUpdate + wallet/heroes/equipment/formation/campaign/idle
│  │  ├─ notification/          Notification + equipment/EquipmentChanges
│  │  └─ battle/                战斗参与者、事件与战报
│  ├─ server/
│  │  ├─ playerstate/           PlayerRecord + 各模块的私有 Dbo
│  │  └─ storage/               SaveEnvelope、RequestReceipt
│  └─ generated/                 excel2pb 生成的双端表协议
├─ tools/                        表生成、构建、测试、运行脚本
├─ docs/                         设计和数据规范
├─ build/                        构建产物、测试日志和截图，忽略提交
└─ runtime/                      开发服务器存档，忽略提交
```

## 多语言：两个文案来源，一个切换入口

| 内容 | 编辑位置 | 运行时方式 |
|---|---|---|
| 页签、按钮、提示、错误信息、数字格式模板 | `client/localization/ui.zh_CN.po` / `ui.zh_TW.po` / `ui.en.po` | Godot TranslationServer、控件自动翻译及 `tr()` |
| 英雄、技能、装备、关卡名称与描述 | 业务 Excel 的 `i18n` 字段 + `table/xlsx/I18N.xlsx` | excel2pb 生成稳定键和 I18N 数据，统一适配器注册为 Godot Translation |
| 等级、属性、余额、战斗结果、挂机收益 | Go 权威快照；规则来自 Excel | Presenter 使用对应语言的 UI 格式模板显示数值 |

UI 不拼接英文、不直接判断 `Cn/Tn/En`，也不保存上一个语言的最终文案。切换语言重新解析文案键，保留当前页面、选中英雄和阵容草稿。切换发生在战斗播放中时，角色名、技能名和战斗信息一起刷新。

详细说明见 [Excel 与多语言](docs/表格与多语言.md)、[权威架构与扩展](docs/架构设计.md)、[协议、同步与存档](docs/协议与存档.md)。

默认存档为单机 `user://offline.pb`、服务器 `runtime/server.pb`。新文件不存在时自动读取同名旧 `.json` 存档，校验并迁移状态和幂等回执，保留原 JSON 文件；存档损坏或版本不兼容会报错，不会清档。业务 proto 单独生成命令为 `./tools/generate_proto.ps1`，修改后仍需要重建 DLL 和服务器。

当前 GameResponse 精简为 `id/code/update/notifications/battle`，通过 `code="ok"` 判断成功。请求协议和 WebSocket 使用 v2，protobuf 存档使用 schema 3。现阶段直接修改协议，不维护旧响应和旧 protobuf 存档的兼容转换。

协议目录参考 idle-rpg 按公开状态、通知、私有状态分层，再按业务模块拆分；同模块的小消息可放在同一文件。生成脚本递归查找协议，先生成到临时目录，成功后同步到客户端与 Go，并清理已删除或重命名协议对应的旧生成文件。Godot 仅生成共享协议，并保留模块目录结构。

## 验证与范围

已验证权威规则的拒绝/回滚、重复请求防重、并发版本冲突、装备占用、挂机封顶、完整六关成长路径；真实 DLL 与 WebSocket 的 protobuf 状态和战报一致。验证包括长连接复用、握手认证/子协议/Origin、二进制消息限制、ping/pong 与无响应连接关闭、断线后重发不重复扣费，以及原有脏模块、通知、版本恢复、原子存档和旧档迁移。Godot smoke 同时验证升级、装备、阵容、战斗播放、三语切换、本地/在线存档隔离，以及丢失响应和空闲断线后的自动重连，界面保持 **193 个静态 Control 节点**。

界面截图在 `build/campaign-zh.png`、`campaign-en.png`、`campaign-tw.png`、`heroes-zh.png`、`equipment-en.png`、`formation-en.png` 等文件中。

这是可玩架构原型：服务器目前只有一个开发档案、文件存储和开发 token，默认监听回环地址。正式联网需要接入账号认证、按玩家隔离的存储、数据库事务、限流与部署监控。**本地 DLL 无法阻止玩家修改本地内存或存档；正式在线模式只相信服务器自行保存、验证和计算的状态，不能信任单机进度。**

当前未提供 Android/macOS/Linux 原生桥接或导出包，也未实现抽卡、商店、付费、社交与实时 PvP。字体使用系统字体；正式跨平台发行应加入可分发字体并补做布局验证。Android 后续联调默认优先 MuMu。
