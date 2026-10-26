# 萌宠优选 · 宠物商城系统

基于 **RuoYi-Vue 3.9.2**（Spring Boot + Vue3）二次开发的宠物商城系统，包含后台管理端、会员端接口与商城业务模块 `ruoyi-mall`。

> 同伴交付的《萌宠优选_后端交接包》内容已全部合并进本仓库根目录（不再保留“交接包”文件夹），并把本地原有文档/脚本中的独有内容合并进来，重复副本已清理。
>
> 协作者推送的 `main` 分支（管理端 10 个页面、9 个 API 模块、10 个公共组件、前端设计文档与验收证据）已合并进 `master`，目录结构统一为仓库根目录平铺，原 `萌宠优选_后端交接包/` 包裹目录已移除（后端内容与平铺版本逐字节相同）。

## 目录结构

```text
超市管理系统/
├─ backend/      后端源码（RuoYi + ruoyi-mall）
├─ admin-ui/     管理前端（RuoYi-Vue3 + Vite，已实现 /mall 与 /merchant 页面；首次需 npm install）
├─ user-ui/      用户前端（Vue3 + Vite，19 个页面；开发端口 81）
├─ config/       配置模板与本机 backend.env（含密码，Git 忽略）
├─ db/           SQL 脚本与执行证据
├─ docs/         需求 / 设计 / 数据库 / 规划 / AI 日志（已合并本地独有版本）
├─ scripts/      DB / Redis 工具与文档生成脚本
├─ setup/        环境预检、建库、启动、停止、冒烟脚本
├─ verify/       验收证据
├─ README.md    本文件
├─ RUNBOOK.md   运行、排错、验收手册
├─ VERSION.txt  交接包版本
└─ *.bat        环境预检、建库、启停、冒烟入口
```

## 快速开始

### 2026-10-27 修复版入口

双击 **`start-mall.bat`**（兼容入口 `start-user-ui.bat`），等待检查完成后打开 [用户商城](http://127.0.0.1:81/)。脚本依次检查 MySQL、Redis、后端健康和前端接口代理。

最新版新增商品收藏、站内通知偏好、登录设备管理、联系手机号修改；修复地址删除保护、并发默认地址、立即购买数量、重复下单、支付回调、后台库存调整及库存流水。升级自动新增 3 张表，保留现有数据。详情见 [功能完善与验收记录](docs/功能完善-v1.2.0.md)。此前修复见 [v1.1.0 记录](docs/修复记录-v1.1.0.md)。

v2.2.1 再次复查修复了多规格下单/取消的数据库死锁，并验证并发关单、库存恢复及等待锁后的最新价格。复现与验收见 [复查记录](docs/复查记录-v2.2.1.md)。

管理端已构建时运行 `start-admin-runtime.bat`，访问 [管理端](http://127.0.0.1:80/)。下面的 npm 命令用于开发；首次安装才需要初始化数据库，日常运行不要重置数据。

后端（需 JDK 17、MySQL 8、Redis 7），在项目根目录执行：

```powershell
.\check-env.bat       # 环境预检
.\init-db.bat         # 初始化 shop 数据库（首次）
.\start-backend.bat   # 启动后端，默认 8080
.\smoke-test.bat      # 冒烟验收
```

管理前端（Node 18+）：

```powershell
cd admin-ui
copy .env.example .env.development   # 首次：生成开发环境变量（接口前缀 /dev-api）
npm install                          # 首次：安装依赖（约 527 个包，可用国内镜像）
npm run dev                          # 默认端口 80，代理到 localhost:8080
```

商城管理端页面已按《管理端前端详细设计 v1.0》实现：`/mall/*` 8 个管理页（工作台、商品管理、商品审核、类目管理、订单管理、会员管理、库存总览、审计日志）+ `/merchant/*` 2 个商家页（我的商品、我的订单）。

```powershell
cd admin-ui
node scripts/mall-check.mjs   # 商城前端静态自检（页面/路由名/权限码/import/SFC 编译）
npm.cmd run build:prod        # 生产构建 → dist/
```

- 商城接口（`/api/admin/**`、`/api/merchant/**`、`/api/upload/**`、`/api/home/**`）统一走 `src/utils/mallRequest.js`；若依接口仍走 `src/utils/request.js`。
- 首次联调前建议执行 `db/04_fix_menu_route_name.sql`：管理端与商家端的 `items`/`orders` 路由同名，需给 3201/3202 补 `route_name`（设计文档 R-01；重跑 `03_seed.sql` 后需再次执行）。

用户端（`user-ui`，客户前台）已实现 19 个页面，直连现有后端，支持桌面与移动端：

- 设计文档：`docs/02-设计文档/用户端前端详细设计_v1.0.md`（§3 真实接口契约 U01–U38、§5 十八个页面逐页设计、§6 请求层/组件/store、§7 十四条关键流程、§9 实施与验收）
- 工程：`user-ui/`（Vue 3 + Vite 6 + Element Plus 按需引入 + Pinia + Vue Router 4），开发端口 **81**，代理 `/api` 与 `/profile` → `http://127.0.0.1:8080`
- 启动：双击 `start-user-ui.bat`，或进入 `user-ui` 执行 `npm.cmd ci`、`npm.cmd run dev`；演示账号 `member1/member123`、`member2/member123`
- 功能：商品浏览筛选、会员账号、宠物档案、收货地址、消息、游客车合并、服务端结算、幂等下单、沙箱支付、订单与收货。
- 校验：在 `user-ui` 执行 `npm.cmd test`、`npm.cmd run check`、`npm.cmd run build`；真实接口验收与浏览器记录见 `verify/user-ui/`；运行、部署及已知边界见 `user-ui/README.md`。
- 最新交付包：[完整商城功能完善版 v2.2.0 ZIP](docs/05-交付包/pet-mall-v2.2.0.zip)（后端 JAR、前后台构建、源码及验收）；[下载与使用说明](docs/05-交付包/README.md)。旧 v1.0.0 仅作历史快照。

更多说明见 `RUNBOOK.md`；交接包原始说明已归档到 `docs/后端交接包_交付说明.md`。

## Git 说明

- 主分支：`master`（整合后的唯一主线）；历史保留协作者的全部提交：平铺化合并 `d439bb5`（双父 `a5e86d5` + `4392d2a`），以及随后 `c71e738`（用户端前端详细设计 v1.0）的合并
- 持续更新的主分支是 `master`；`main` 仅作历史兼容保留，不保证与最新版同步
- 当前远端：`origin` → GitHub `https://github.com/CHEN0611mci/yao.git`
- 日常同步：`git push origin master`
- 只跟踪项目源码 / SQL / 文档 / 脚本，及 `.gitattributes`、`.gitignore` 等必要文件
- 本机环境与辅助文件不入库：`dev-redis/`、`msi-logs/`、`mysql-backup/`、`release/`、`ch09_png/`、课程笔记、安装日志等
- `node_modules/`、`target/`、`*.jar`、`.env*`、`config/backend.env`、日志与备份由 `.gitignore` 排除
