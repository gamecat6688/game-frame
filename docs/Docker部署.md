# Docker Compose 部署

在项目根目录执行。需要 Docker Engine / Docker Desktop 的 Linux 容器环境、Docker Compose，以及用于首次生成令牌的 Python。

```powershell
python tools/init_docker.py
docker compose up -d --build --wait
python tools/configure_docker_client.py
docker compose ps
```

默认启动项目 `game-frame` 的 `server` 服务，WebSocket 为 `ws://127.0.0.1:18080/ws`，健康检查为 `http://127.0.0.1:18080/health`。仅绑定本机，游戏命令仍只通过 WebSocket 传输。

`tools/run.ps1 -Server` 使用相同默认端口，运行 Compose 前需停止该开发服务器，或按下文修改 `GAME_PORT`。仅构建和启动容器不需要 Windows 原生桥接工具链；连接 Godot 客户端时仍需先完成客户端构建。

## 镜像与编排

- `Dockerfile` 使用 Go 1.26.4 多阶段构建，在 `CGO_ENABLED=0` 下执行 `go test ./internal/... ./cmd/server`，再编译独立服务器；不构建或测试 Windows DLL 宿主。最终 scratch 镜像包含服务器、CA 证书和预设所有权的数据目录，不需要 Godot、DLL、MinGW、Excel 或 Python。
- 镜像使用已有的生成代码和 `game/data/` 表数据。修改 proto 或 Excel 后，先执行相应生成脚本，再重新构建镜像。Docker 构建不会运行表导出，也不会更新单机 DLL。
- `.dockerignore` 仅允许服务器构建源码进入上下文，排除客户端、工作簿、本地存档和凭据。
- `compose.yaml` 配置非 root 用户 `10001:10001`、只读根文件系统、资源上限、日志轮转、自动重启与健康检查。
- 服务器内置 `-healthcheck-url`，因此容器内不依赖 shell 或 curl。Docker 健康状态用于诊断与 `up --wait`；单纯变成 unhealthy 不会触发 `restart: unless-stopped`，进程退出才会触发该策略。

## 连接令牌与客户端

首次运行 `tools/init_docker.py` 会生成随机令牌到 `runtime/docker/game-token`，已有文件不会覆盖。该目录已被 Git 忽略，令牌不会写进镜像、Compose 环境变量或命令行参数。Compose 将文件挂载为 `/run/secrets/game_token`，服务器通过 `-token-file` 读取；缺失、空白、多行或过大的文件会导致启动失败。

初始化脚本使用 `secrets.token_hex(32)` 生成令牌；再次运行只校验并保留已有文件，不会轮换。服务端读取的原始文件上限为 4096 字节，去掉首尾空白后必须为非空单行且不含 NUL。脚本生成文件末尾包含换行，属于允许的首尾空白。

Godot 客户端继续使用 `gameframe.v2` 子协议和 `Authorization: Bearer <token>` 握手。启动容器后执行：

```powershell
python tools/configure_docker_client.py
```

脚本调用 `docker compose config --format json` 和 `docker compose port server 18080`，读取实际映射端口和 secret 文件，将连接地址及令牌写入 `client/override.cfg`，不会打印令牌。它会覆盖整个文件，仅写入 `[game]` 下的 `server_url` 和 `development_token`；自行维护其他覆盖设置时需要保留备份。Godot 启动时用它覆盖项目默认连接设置。重启客户端，切换到“在线冒险”后即可访问容器。修改端口或轮换令牌后重新运行脚本并重启客户端。

默认 `prototype-local` 不能连接此次部署。若要恢复连接 `tools/run.ps1 -Server` 启动的默认开发服务器，先移走 `client/override.cfg` 并重启客户端。该令牌仅为当前单开发账号原型提供连接验证，不能替代正式账号登录、用户隔离和会话签发。

Compose 本地 file secret 通过文件挂载提供，不是外部密钥管理服务。限制宿主机对令牌文件的访问；Linux 上目录可设为 `0700`，文件需允许容器 UID 读取。轮换令牌后用 `docker compose up -d --force-recreate --wait` 重新加载，并同步客户端凭据。

## 端口和访问范围

需要修改默认设置时，把 `.env.example` 复制为 `.env`：

```dotenv
GAME_BIND_IP=127.0.0.1
GAME_PORT=18080
GAME_TOKEN_FILE=./runtime/docker/game-token
```

`GAME_TOKEN_FILE` 是凭据文件路径，不是令牌内容。指定其他路径时先运行 `python tools/init_docker.py --token-file <路径>` 创建文件。

局域网联调可把绑定地址改为指定的局域网 IP，客户端改用对应主机地址。公网部署应使用 HTTPS 反向代理提供 `wss://`，并转发 WebSocket Upgrade；此编排不配置域名、TLS 证书或公网入口。

客户端配置脚本服务于运行在同一宿主机上的本地 Compose。绑定 `0.0.0.0` 或 `::` 时，它会将客户端地址转换成 `127.0.0.1`；其他设备不能直接使用该回环地址。连接远程主机或反向代理时，在客户端自己的 `override.cfg` 中配置可达的 `server_url` 和对应令牌。

## 服务器启动参数

这些参数由 `game/cmd/server/main.go` 定义。直接运行 `build/server.exe` 时使用下列默认值；Docker 通过镜像 CMD 覆盖监听地址、存档路径和令牌文件。

| 参数 | 默认值 | 行为 |
|---|---|---|
| `-listen` | `127.0.0.1:18080` | HTTP 健康检查和 WebSocket 共用监听地址 |
| `-save` | `runtime/server.pb` | 宿主控制的存档路径 |
| `-token` | `prototype-local` | 本地开发令牌；部署时使用 secret 文件 |
| `-token-file` | 空 | 从文件读取令牌，优先于 `-token`；启动时读取一次 |
| `-healthcheck-url` | 空 | 以 2 秒 HTTP 超时检查指定地址并退出，不加载存档或启动业务服务 |

健康检查要求 HTTP 200 且响应体恰为 `ok`。`/health` 只反映 HTTP 服务可响应，不执行存档写入或业务事务。所有已认证连接共用启动时创建的一个 Runtime 和一个存档。

## 存档与更新

容器把服务器存档写到 `/data/server.pb`，对应默认命名卷 `game-frame_game_data`；与宿主机 `runtime/server.pb` 及客户端单机存档分离。新建卷会自动获得容器写入用户所需的目录所有权。

```powershell
# 更新服务器，命名卷中的存档保留
docker compose up -d --build --wait

# 查看状态和日志
docker compose ps
docker compose logs -f --tail 100 server

# 停止并移除容器，保留存档卷
docker compose down

# 再次启动
docker compose up -d --wait
```

备份时可先 `docker compose stop server`，再用 `docker compose cp server:/data/server.pb ./server-backup.pb` 导出文件，然后 `docker compose up -d --wait`。恢复前同样停服，将兼容的服务端存档复制回 `/data/server.pb`，确保 UID/GID 10001 可读该文件并可写 `/data` 目录。兼容性包括 PlayerRecord schema 3 和与镜像内 `Rules.Version` 一致的配置版本；加载失败会中止启动，不会静默清档。不要导入客户端单机存档。

`docker compose down --volumes` 会删除存档卷，日常停止或更新不要使用它。当前文件存储只能单实例写入，请勿对 `server` 使用 `--scale`；多实例需要先接入按玩家分片或支持事务的数据库。

## 验证

```powershell
python -m pip install -r tools/requirements-tests.txt
./tools/generate_proto.ps1
python tools/init_docker.py
docker compose build
python tools/test_docker.py
```

测试创建独立的 `game-frame-smoke-<时间戳>` 项目、随机端口和临时卷，检查健康状态、非 root/只读配置、连接认证、WebSocket 业务写入，以及强制重建容器后的存档和幂等回执恢复。最后只删除该测试项目及其临时卷，不修改默认部署进度。

测试使用 `--no-build` 启动已有的 `game-frame-server:local` 镜像，复用当前 Compose 配置中的 secret 文件；因此必须先完成镜像构建、凭据准备和 Python 协议生成。`build.ps1 -Test` 不会自动执行这项容器测试。

编排依据：[Docker Compose 服务配置](https://docs.docker.com/reference/compose-file/services/)、[Compose secrets](https://docs.docker.com/reference/compose-file/secrets/)、[Compose volumes](https://docs.docker.com/reference/compose-file/volumes/)。
