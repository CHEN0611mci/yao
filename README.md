# 萌宠优选 · 宠物商城系统

基于 **RuoYi-Vue 3.9.2**（Spring Boot + Vue 3）二次开发的宠物商城系统：后端业务模块 `ruoyi-mall`、若依管理端 `admin-ui`、商城用户端 `user-ui`。

> 从仓库完整 clone 后，按下面「四步」即可同时跑通**管理端**与**用户端**。前端依赖安装、生产构建、管理端 `.env.production` 全部由脚本自动完成，不需要手工复制环境文件。

## 目录结构

```text
├─ backend/      后端源码（RuoYi + ruoyi-mall 业务模块）
├─ admin-ui/     管理端（RuoYi-Vue3 + Vite，/mall 8 页 + /merchant 2 页）
├─ user-ui/      用户端（Vue 3 + Vite，19 个页面，桌面 + 移动）
├─ config/       配置模板 backend.env.example 与本机 backend.env（含密码，Git 忽略）
├─ db/           建库 / 种子 / 校验 SQL 与执行证据
├─ docs/         版本记录、AI 编程日志、整合说明
├─ scripts/      装机期工具（安装 MySQL/Redis、建库导入、文档配图）
├─ setup/        运行期脚本（预检、建库、构建、启动、停止、冒烟）
├─ verify/       验收证据
├─ start-all.bat           一次启动：后端 + 用户端(81) + 管理端(80)
├─ start-mall.bat          仅用户端（含后端）
├─ start-admin-runtime.bat 仅管理端（首次自动安装依赖并构建）
├─ check-env.bat / init-db.bat / smoke-test.bat / stop-backend.bat
└─ README.md / RUNBOOK.md / VERSION.txt
```

## 环境要求

| 组件 | 版本 | 必需 | 说明 |
|---|---|---|---|
| JDK | 17+ | 是 | 运行后端；可用 `config/backend.env` 的 `JAVA_HOME` 指定 |
| MySQL | 8.0 | 是 | 库 `shop`；`DB_PASSWORD` 写在 `config/backend.env` |
| Redis | 7.x | 是 | 默认 `127.0.0.1:6379`，有密码时填 `REDIS_PASSWORD` |
| Node.js | 18+ | 是 | 构建并托管 `user-ui` / `admin-ui` 静态产物 |
| Maven | 3.9+ | 否 | 仅当没有 `dist/ruoyi-admin.jar`、需要从源码构建时使用 |

全新机器还没有 MySQL / Redis：先运行 `scripts\MySQL初始化.bat` 与 `scripts\Redis安装.bat`，分工见 `scripts/README.md`。

## 从仓库下载后的四步

```powershell
.\check-env.bat        # 1. 环境预检（JDK/MySQL/Redis/Node/端口/文件），报告写入 setup\env-report.txt
.\init-db.bat          # 2. 首次建库：空库执行 01→02→03；已有库走增量升级，不覆盖数据
.\start-all.bat        # 3. 启动后端(8080) + 用户端(81) + 管理端(80)
.\smoke-test.bat       # 4. 可选：接口与权限冒烟验收
```

首次执行 `start-all.bat` 会自动：`npm ci` 安装两个前端依赖 → 生成 `admin-ui\.env.production`（`/prod-api`）→ 构建 `dist` → 启动静态服务并校验 `/api/health` 与 `/prod-api/api/health`。之后重复执行是增量、幂等的，已运行的进程会复用。

### 访问地址与演示账号

| 入口 | 地址 | 账号 |
|---|---|---|
| 用户端 | http://127.0.0.1:81/ | `member1/member123`、`member2/member123` |
| 管理端 | http://127.0.0.1:80/ | `admin/admin123`、`merchant1/merchant123`、`reviewer/reviewer123` |
| 后端 | http://127.0.0.1:8080/api/health | Swagger：`/swagger-ui.html` |

管理端登录页带图形验证码（`captchaEnabled=true`，校验值存在 Redis）；冒烟脚本会自动从 Redis 取答案，浏览器中需手工输入。

### 只启动其中一端 / 换端口

```powershell
.\start-mall.bat                     # 仅用户端（含后端）
.\start-admin-runtime.bat            # 仅管理端；后端未启动时可加 -StartBackend
.\start-admin-runtime.bat -AdminPort 8081
.\start-all.bat -UserPort 8181 -AdminPort 8180
```

80 端口被系统服务占用时，用 `-AdminPort 8081` 即可；`start-*.bat` 会把参数原样透传给对应的 `setup\start-*.ps1`。

## 单独构建与开发

```powershell
# 两端统一构建：自动 npm ci + 生成 .env.* + 增量构建；-Force 强制重装依赖并重建
powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Both

# 管理端开发模式（Vite dev，端口 80，/dev-api 代理到 8080）
cd admin-ui
copy .env.example .env.development
npm install
npm run dev

# 用户端开发模式（端口 81，/api 与 /profile 代理到 8080）
cd user-ui
npm.cmd ci
npm.cmd run dev
```

`admin-ui/dist`、`user-ui/dist`、`node_modules/` 都是脚本生成的产物，不入库；`.env.production` / `.env.development` 也在首次构建时由 `.env.example` 自动生成（已存在的文件不会被覆盖）。

## 功能与版本记录

- **v2.4.0（本版）**：仓库整合，下载即可完整运行两端。新增 `setup/build-ui.ps1`、`setup/start-admin.ps1`、`setup/start-all.ps1`、`start-all.bat`；管理端不再需要手工创建 `.env.production`；清理若依遗留批处理与已被合并的重复 SQL。详见 [整合说明](docs/整合说明-v2.4.0.md)。
- **v2.3.0**：会员会话索引，设备查询 / 撤销 / 改密退出全部设备不再遍历全站令牌。见 [会话优化与验收](docs/会话优化-v2.3.0.md)。
- **v2.2.2**：修复分类移位导致三级分类异常、数组空项返回服务器错误、取消订单间隙锁、提交消息耗尽连接池。见 [复查记录](docs/复查记录-v2.2.2.md)。
- **v2.2.1**：修复多规格下单 / 取消的数据库死锁，验证并发关单与库存恢复。见 [复查记录](docs/复查记录-v2.2.1.md)。
- **v1.2.0 / v1.1.0**：商品收藏、通知偏好、登录设备管理、联系手机号；修复地址删除保护、并发默认地址、立即购买数量、重复下单、支付回调、后台库存调整及库存流水。见 [功能完善与验收记录](docs/功能完善-v1.2.0.md)、[修复记录](docs/修复记录-v1.1.0.md)。

### 管理端

`/mall/*` 8 个管理页（工作台、商品管理、商品审核、类目管理、订单管理、会员管理、库存总览、审计日志）+ `/merchant/*` 2 个商家页（我的商品、我的订单）。

- 商城接口（`/api/admin/**`、`/api/merchant/**`、`/api/upload/**`、`/api/home/**`）走 `src/utils/mallRequest.js`；若依接口走 `src/utils/request.js`。
- 首次联调建议执行 `db/04_fix_menu_route_name.sql`：管理端与商家端的 `items`/`orders` 路由同名，需给 3201/3202 补 `route_name`（重跑 `03_seed.sql` 后要再执行一次）。
- 前端静态自检：`cd admin-ui && node scripts/mall-check.mjs`。

### 用户端

19 个页面，直连后端，桌面与移动端自适应：商品浏览筛选、会员账号、宠物档案、收货地址、消息、游客车合并、服务端结算、幂等下单、沙箱支付、订单与收货。

- 工程说明见 [user-ui/README.md](user-ui/README.md)；接口与浏览器验收记录见 [verify/user-ui](verify/user-ui/README.md)。
- 校验：`cd user-ui && npm.cmd test && npm.cmd run check && npm.cmd run build`。

## 排错速查

| 现象 | 处理 |
|---|---|
| 管理端入口提示"后端未就绪" | 先运行 `start-mall.bat`，或给管理端入口加 `-StartBackend` |
| 管理端页面空白 / 接口 404 | `powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Admin -Force` 后重新启动 |
| `npm ci` 很慢或失败 | 切换镜像：`npm config set registry https://registry.npmmirror.com` |
| 80 / 81 端口被占用 | `start-all.bat -UserPort 8181 -AdminPort 8180` |
| 后端启动失败 | 看 `logs\console.log`、`logs\console.err.log`，访问 `http://127.0.0.1:8080/api/health` |
| 验证码一直错误 | 确认后端与本机 Redis 是同一个实例；不要复用已消费的 uuid |

换机准备、数据库重置与备份、安全清单、内存不足排错见 `RUNBOOK.md`。

## Git 说明

- 主分支：`master`（整合后的唯一主线），历史保留协作者提交（平铺化合并 `d439bb5`、`c71e738` 等）；`main` 仅作历史兼容。
- 远端：`origin` → `https://github.com/CHEN0611mci/yao.git`，日常同步 `git push origin master`。
- 只跟踪源码 / SQL / 文档 / 脚本 / 配置模板；`node_modules/`、`dist/`、`target/`、`*.jar`、`.env*`、`config/backend.env`、`logs/`、`run/`、`verify/smoke-result.txt` 均由 `.gitignore` 排除。
- 本机环境与辅助文件不入库：`dev-redis/`、`msi-logs/`、`mysql-backup/`、`release/` 等。

