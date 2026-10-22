# 萌宠优选 · 超市/宠物商城管理系统

基于 **RuoYi-Vue 3.9.2**（Spring Boot + Vue3）二次开发的宠物商城系统，包含后台管理端、会员端接口与商城业务模块（`ruoyi-mall`）。

> 课程/小组项目交付仓库。演示账号仅用于本地验收，正式部署前请修改密码与 `TOKEN_SECRET`。

## 1. 仓库内容

```text
超市管理系统/
├─ 萌宠优选_后端交接包/            ← 主体交付包（源码 + SQL + 启动脚本 + 文档）
│  ├─ backend/                     RuoYi 3.9.2 多模块源码（含 ruoyi-mall）
│  ├─ admin-ui/                    RuoYi-Vue3 管理前端源码
│  ├─ db/                          01_base / 02_pet_mall / 03_seed / verify / rollback
│  ├─ config/backend.env.example   后端配置模板（复制为 backend.env 后填写密码）
│  ├─ setup/                       环境预检、建库、启动、停止、冒烟脚本
│  ├─ docs/                        需求 / 设计 / 数据库 / 测试 / AI 日志
│  ├─ README.md                    交接包快速开始（推荐先看）
│  └─ RUNBOOK.md                   运行、排错、验收手册
└─ docs/                           项目级需求与设计文档
```

以下内容**未纳入仓库**（`.gitignore` 排除，避免仓库臃肿与信息泄露）：

| 排除项 | 原因 |
|---|---|
| `mysql-8.0.46-winx64/` | 本机 MySQL 完整安装目录，请自行安装 MySQL 8.0 |
| `RuoYi-Vue-master/` | 原版若依基座副本，功能已被 `backend/` 覆盖，且含本机明文密码 |
| `萌宠优选_后端交接包_20261019/`、`*.zip` | 历史版本 / 压缩包，与最新交接包重复 |
| `**/target/`、`**/node_modules/`、`*.jar` | Maven / npm 构建产物，可重新生成 |
| `config/backend.env`、`_start.ps1` 等 | 含本机数据库密码与路径 |
| `*-check.txt`、`*.log`、`*.pid` | 本机环境探测与运行日志 |

> `dist/ruoyi-admin.jar` 因体积原因未入库；`start-backend.bat` 在没有 JAR 时会自动用 Maven 从源码构建。

## 2. 环境要求

| 软件 | 版本 | 说明 |
|---|---|---|
| Windows | 10/11 | 启动脚本基于 PowerShell 5.1+ |
| JDK | 17+（推荐 17/21） | 需可执行 `java -version` |
| MySQL | 8.0 | 端口 3306，需 root 密码 |
| Redis | 7.x | 端口 6379，登录 / Token / 验证码依赖 |
| Maven | 3.9.x | 仅在需要从源码构建后端时使用 |
| Node.js | 18+（建议 20/24） | 仅运行管理前端时需要 |

## 3. 快速开始（后端）

```powershell
cd 萌宠优选_后端交接包

# 1) 启动 MySQL 与 Redis，确认：
mysql -uroot -p -e "SELECT VERSION();"
redis-cli ping      # 期望 PONG

# 2) 环境预检
.\check-env.bat

# 3) 初始化数据库 shop（按提示输入 root 密码）
.\init-db.bat

# 4) 配置后端
copy config\backend.env.example config\backend.env
#    编辑 backend.env，填写 DB_PASSWORD

# 5) 启动（无 dist JAR 时自动 Maven 构建）
.\start-backend.bat

# 6) 验收（预期 PASS=30 FAIL=0）
.\smoke-test.bat
```

启动成功后：

- Swagger：<http://localhost:8080/swagger-ui.html>
- 验证码接口：<http://localhost:8080/captchaImage>
- 停止：`.\stop-backend.bat`

## 4. 快速开始（管理前端）

```bash
cd 萌宠优选_后端交接包/admin-ui
npm install
npm run dev
```

默认请求后端 `http://localhost:8080`（见 `vite.config.js`），请先启动后端。

## 5. 演示账号

| 账号 | 密码 | 用途 |
|---|---|---|
| `admin` | `admin123` | 后台超级管理员 |
| `merchant1` | `merchant123` | 商家（`merchant_id=9001`） |
| `reviewer` | `reviewer123` | 审核员（最小权限） |
| `member1` / `member2` | `member123` | 前台会员（数据隔离演示） |

## 6. 已验收项

- Maven：8 个模块 `BUILD SUCCESS`
- 数据库：`verify.sql` 35 项 PASS（`shop` 库 45 张表）
- 后端冒烟：30 项 PASS（验证码、公开商品、会员登录/地址/购物车/订单、后台商品/分类/会员/订单/库存/看板）
- 权限隔离：商家不可进后台管理、审核员仅看待审队列、会员 Token 不可访问后台接口

详细步骤与排错见 `萌宠优选_后端交接包/README.md` 与 `RUNBOOK.md`。
