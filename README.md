# 萌宠优选 · 宠物商城系统

基于 **RuoYi-Vue 3.9.2**（Spring Boot + Vue3）二次开发的宠物商城系统，包含后台管理端、会员端接口与商城业务模块 `ruoyi-mall`。

> 同伴交付的《萌宠优选_后端交接包》内容已全部合并进本仓库根目录（不再保留“交接包”文件夹），并把本地原有文档/脚本中的独有内容合并进来，重复副本已清理。

## 目录结构

```text
Aiwork5/
├─ backend/      后端源码（RuoYi + ruoyi-mall）
├─ admin-ui/     管理前端（已含 node_modules、.env、package-lock）
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
npm run dev           # 默认端口 80，代理到 localhost:8080
```

商城管理端页面已按《管理端前端详细设计 v1.0》实现：`/mall/*` 8 个管理页（工作台、商品管理、商品审核、类目管理、订单管理、会员管理、库存总览、审计日志）+ `/merchant/*` 2 个商家页（我的商品、我的订单）。

```powershell
cd admin-ui
node scripts/mall-check.mjs   # 商城前端静态自检（页面/路由名/权限码/import/SFC 编译）
npm.cmd run build:prod        # 生产构建 → dist/
```

- 商城接口（`/api/admin/**`、`/api/merchant/**`、`/api/upload/**`、`/api/home/**`）统一走 `src/utils/mallRequest.js`；若依接口仍走 `src/utils/request.js`。
- 首次联调前建议执行 `db/04_fix_menu_route_name.sql`：管理端与商家端的 `items`/`orders` 路由同名，需给 3201/3202 补 `route_name`（设计文档 R-01；重跑 `03_seed.sql` 后需再次执行）。

用户端（`user-ui`，客户前台）设计已定稿，工程尚未创建：

- 设计文档：`docs/02-设计文档/用户端前端详细设计_v1.0.md`（§3 真实接口契约 U01–U38、§5 十八个页面逐页设计、§6 请求层/组件/store、§7 十四条关键流程、§9 实施与验收）
- 规划形态：新建 `user-ui/`（Vue 3 + Vite 6 + Element Plus + Pinia + Vue Router 4），开发端口 **81**，代理 `/api` 与 `/profile` → `http://localhost:8080`
- 实施入口：按设计文档 §9.1 WBS 建卡、§9.3 十五步联调、§9.4 DoD 验收；演示账号 `member1/member123`、`member2/member123`

更多说明见 `RUNBOOK.md`；交接包原始说明已归档到 `docs/后端交接包_交付说明.md`。

## Git 说明

- 分支：`main`（本地仓库，暂无远程）
- 只跟踪项目源码 / SQL / 文档 / 脚本，及 `.gitattributes`、`.gitignore` 等必要文件
- 本机环境与辅助文件不入库：`dev-redis/`、`msi-logs/`、`mysql-backup/`、`release/`、`ch09_png/`、课程笔记、安装日志等
- `node_modules/`、`target/`、`*.jar`、`.env*`、`config/backend.env`、日志与备份由 `.gitignore` 排除
