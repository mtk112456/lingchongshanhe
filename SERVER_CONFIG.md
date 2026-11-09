# 服务器配置与账号凭据管理文档

> **创建日期**：2026-11-09  
> **适用范围**：班级量化考核系统、阿里云公网服务器、家庭实验室本地服务器、灵宠山河游戏部署环境  
> **重要说明**：本文档包含服务器与数据库敏感凭据，请妥善保管，禁止提交至公开代码仓库。

---

## 目录
1. [阿里云服务器 (公网 Cloud Server)](#1-阿里云服务器-公网-cloud-server)
2. [家庭实验室服务器 (本地/内网 Home Lab)](#2-家庭实验室服务器-本地内网-home-lab)
3. [双机实时同步机制 (Sync & Pipeline)](#3-双机实时同步机制-sync--pipeline)
4. [本地游戏切片开发环境 (Game Local Dev)](#4-本地游戏切片开发环境-game-local-dev)
5. [灵宠山河多端部署拓扑规划 (Deployment Topology)](#5-灵宠山河多端部署拓扑规划-deployment-topology)

---

## 1. 阿里云服务器 (公网 Cloud Server)

### 1.1 主机基础信息
| 属性 | 配置值 / 说明 |
|---|---|
| **公网 IP** | `8.137.146.165` |
| **绑定域名** | `qnengs.tech`、`www.qnengs.tech`、`qi.qnengs.tech` |
| **操作系统** | Ubuntu 22.04 LTS (x86_64, Linux 5.15 内核) |
| **系统职责** | 生产站点对外访问入口、Nginx 反向代理、MySQL 镜像备库；后续规划部署实时对战服（WebSocket/Redis） |

### 1.2 SSH 登录凭据
| 属性 | 配置值 |
|---|---|
| **SSH 端口** | `22` |
| **登录用户** | `root` |
| **登录密码** | `Mm2013456789@` |
| **本地快捷命令** | `node C:\Users\MTK\.zcode\workspace\default\tools\srv_aliyun.js "<命令>"` |

### 1.3 Web 服务 (Nginx)
| 属性 | 配置值 / 说明 |
|---|---|
| **Web 站点根目录** | `/var/www/html` |
| **Nginx 站点配置** | `/etc/nginx/sites-available/teaching`（符号链接至 `/etc/nginx/sites-enabled/teaching`） |
| **证书管理** | Certbot 自动签发 HTTPS 证书 |
| **PHP 运行环境** | PHP-FPM（与 Nginx 通过 fastcgi 协议通信） |

### 1.4 数据库服务 (MariaDB 原生)
| 属性 | 配置值 |
|---|---|
| **数据库类型** | MariaDB 10.6.23 (原生 systemd 服务) |
| **数据库名称** | `class_manager` |
| **业务用户名** | `class_user` |
| **业务密码** | `ClassManager2026!` |
| **常用连接命令** | `mysql -uclass_user -pClassManager2026! class_manager` |

---

## 2. 家庭实验室服务器 (本地/内网 Home Lab)

### 2.1 主机基础信息
| 属性 | 配置值 / 说明 |
|---|---|
| **Tailscale 内网 IP** | `100.88.22.117` |
| **操作系统** | Linux x86_64（带有 Docker、Docker Compose、1Panel 面板） |
| **公网映射机制** | Cloudflare Tunnel 系统服务（无需暴露路由器端口，由 `cloudflared` 反向打通） |
| **系统职责** | 班级量化考核系统**核心唯一主库**、本地 Docker 应用中心；后续部署游戏异步 API (`lingchong-api`) |

### 2.2 SSH 登录凭据
| 属性 | 配置值 |
|---|---|
| **SSH 端口** | `22` |
| **登录用户** | `mtk` |
| **登录密码** | `M2013456789` |
| **本地快捷命令** | `node C:\Users\MTK\.zcode\workspace\default\tools\srv.js "<命令>"` |
| **文件传输工具** | `node C:\Users\MTK\.zcode\workspace\default\tools\srv_get.js` / `srv_put.js` |

### 2.3 教学系统栈 (teaching-app Docker Compose)
| 属性 | 配置值 / 说明 |
|---|---|
| **栈项目目录** | `/opt/home-lab/server-deploy/stacks/teaching-app` |
| **配置文件路径** | `/opt/home-lab/server-deploy/stacks/teaching-app/.env` |
| **代码挂载目录** | `/srv/teaching/html`（挂载至容器内部 `/var/www/html`） |
| **上传附件目录** | `/srv/teaching/uploads` |
| **Docker Compose 文件** | `/opt/home-lab/server-deploy/stacks/teaching-app/compose.yml` |
| **核心容器** | - `teaching-app-web-1` (PHP 8.x + Apache，主机端口映射 `8080:80`)<br>- `teaching-app-db-1` (MariaDB 10.6，接入 `teaching-app_default` 网络) |

### 2.4 数据库配置 (teaching-app-db-1 容器)
| 属性 | 配置值 |
|---|---|
| **数据库类型** | MariaDB 10.6（Docker 容器运行） |
| **数据库名称** | `class_manager` |
| **业务用户名** | `class` |
| **业务密码** | `a110b11598edaf198fb9b4728d0a5c05feb5e8057408d172` |
| **Root 用户密码** | `6c2eb0dc660657b31ed096358ff0d81046bb9491ed3c5784` |
| **内部连接主机** | `db`（或容器名 `teaching-app-db-1`），端口 `3306` |
| **安全策略** | **3306 端口未对外发布**，仅限 Docker `teaching-app_default` 内部网络直连 |
| **容器内连库命令** | `docker exec teaching-app-db-1 mysql -uclass -pa110b11598edaf198fb9b4728d0a5c05feb5e8057408d172 class_manager` |

### 2.5 家庭服务器其他常驻服务参考
- **AI 作文批改引擎**：`essay-grader`（容器运行，本地监听 `127.0.0.1:8110`）
- **Vaultwarden 密码库**：`100.88.22.117:8081`
- **Talebook 书库**：`100.88.22.117:8082`
- **Jellyfin 影音**：`0.0.0.0:8096`
- **qBittorrent**：`0.0.0.0:8085`
- **1Panel 监控与运维**：Prometheus (`9090`)、Grafana (`3000`)、AdGuard Home 等

---

## 3. 双机实时同步机制 (Sync & Pipeline)

本机开发机配置了基于 Node.js 的实时双向推送脚本，代码改动后自动通过 SFTP 双发：

| 属性 | 配置值 / 说明 |
|---|---|
| **本机工程目录** | `D:\DeskBox\班级量化考核系统\班级量化考核管理系统网页前后端` |
| **双机同步脚本** | `C:\Users\MTK\.zcode\workspace\default\tools\watch_sync.js` |
| **同步日志文件** | `C:\Users\MTK\.zcode\workspace\default\tools\sync.log` |
| **常驻守护运行** | `supervisor.cmd` / `teaching_sync.vbs` |
| **同步目标 1 (Home)** | `100.88.22.117:22` (用户 `mtk`) -> `/srv/teaching/html` |
| **同步目标 2 (Aliyun)** | `8.137.146.165:22` (用户 `root`) -> `/var/www/html` |
| **排除过滤目录** | `node_modules`, `uploads`, `output`, `scratch`, `tmp`, `.git` |
| **保护文件 (不覆盖)** | `LicenseManager.php`, `config.local.php` 等 |

---

## 4. 本地游戏切片开发环境 (Game Local Dev)

当前《青竹文房·灵宠山河》项目切片版（Milestone A）本地自闭环测试环境参数：

| 服务组件 | 本地参数 | 说明 / 登录凭据 |
|---|---|---|
| **测试 MariaDB** | `127.0.0.1:3307` | 便携版路径：`D:\DeskBox\游戏\tools\mariadb\mariadb-11.4.9-winx64`<br>数据库：`qingzhu_slice_test`<br>用户：`qingzhu_test` / `qingzhu2026`（root 密码为空） |
| **切片 API 端口** | `http://127.0.0.1:8080/api/` | 启动脚本：`D:\DeskBox\游戏\server\slice\start_api.ps1`<br>健康检查：`http://127.0.0.1:8080/api/health` |
| **测试学生账号** | `青竹一` ~ `青竹四`<br>`墨点一` ~ `墨点四` | 密码统一为：`slice2026`<br>对局代号：`SLICE_A` |
| **测试教师账号** | `teacher` | 密码：`teacher2026` |
| **自动化测试套件** | `server/slice/tests/run.php` | 涵盖鉴权、冲突结算、快照幂等、积分兑换等 14 项完整通过 |

---

## 5. 灵宠山河多端部署拓扑规划 (Deployment Topology)

根据架构设计方案（`deploy/lingchong/CLOUD.md`），游戏上线后的服务器职责分工如下：

```text
                           Cloudflare DNS
                 ┌────────────────┴────────────────┐
                 ▼                                 ▼
        game.yourdomain.com               rt.yourdomain.com
                 │                                 │
         Cloudflare Tunnel                 Cloudflare Tunnel / TLS
                 │                                 │
                 ▼                                 ▼
       【家庭实验室 Home Lab】              【阿里云服务器 Aliyun】
    - teaching-app (班级系统)            - lingchong-rt (实时房间服/WebSocket)
    - MariaDB (唯一主库 class_manager)   - Redis (实时战场房间缓存)
    - lingchong-api (异步回合制 API)
                 ▲                                 │
                 └──────── Tailscale 内网通道 ─────┘
                    (RT 服只通过内部 API 回写结果，不直连 3306)
```

### 关键安全与部署原则：
1. **单一主库原则**：以家庭实验室 MariaDB 为唯一数据源，不开放 `3306` 公网访问。
2. **异步 API 就近接入**：`lingchong-api` 容器加入 `teaching-app_default` 网络，同机直连访问 `db:3306`。
3. **安全隔离**：云端实时服（RT）不持有数据库密码，仅持有内部 Service Key，通过 Tailscale 内网调用家庭实验室内部接口。
4. **积分安全红线**：积分兑换只在现有 `shop_orders` 表中追加类型为 `game_recharge` 的订单记录，不直接改动 `students.score`。
