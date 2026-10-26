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

更多说明见 `RUNBOOK.md`；交接包原始说明已归档到 `docs/后端交接包_交付说明.md`。

## Git 说明

- 分支：`main`（本地仓库，暂无远程）
- 只跟踪项目源码 / SQL / 文档 / 脚本，及 `.gitattributes`、`.gitignore` 等必要文件
- 本机环境与辅助文件不入库：`dev-redis/`、`msi-logs/`、`mysql-backup/`、`release/`、`ch09_png/`、课程笔记、安装日志等
- `node_modules/`、`target/`、`*.jar`、`.env*`、`config/backend.env`、日志与备份由 `.gitignore` 排除
