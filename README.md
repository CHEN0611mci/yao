# 萌宠优选 · 宠物商城系统

基于 **RuoYi-Vue 3.9.2**（Spring Boot + Vue3）二次开发的宠物商城系统，包含后台管理端、会员端接口与商城业务模块 `ruoyi-mall`。

> 本仓库已把同伴交付的《萌宠优选_后端交接包》与本地原有的文档、SQL、脚本合并为同一套：重复副本已去重，旧版若依基座副本已移除，项目统一放在 `shop/萌宠优选_后端交接包/`。

## 目录结构

```text
Aiwork5/
├─ shop/
│  └─ 萌宠优选_后端交接包/        唯一项目目录
│     ├─ backend/                 后端源码（RuoYi + ruoyi-mall）
│     ├─ admin-ui/                管理前端（已含 node_modules、.env、package-lock）
│     ├─ config/backend.env       本机后端配置（含 DB 密码，Git 忽略）
│     ├─ db/  docs/  scripts/  setup/  verify/
│     ├─ README.md  RUNBOOK.md    交接包说明 / 排错与验收手册
│     └─ *.bat                    环境预检、建库、启动、冒烟脚本
├─ README.md（本文件）
├─ .gitattributes
└─ .gitignore
```

## 快速开始

后端（需 JDK 17、MySQL 8、Redis 7）：

```powershell
cd shop\萌宠优选_后端交接包
.\check-env.bat       # 环境预检
.\init-db.bat         # 初始化 shop 数据库（首次）
.\start-backend.bat   # 启动后端，默认 8080
.\smoke-test.bat      # 冒烟验收
```

管理前端（Node 18+）：

```powershell
cd shop\萌宠优选_后端交接包\admin-ui
npm run dev           # 默认端口 80，代理到 localhost:8080
```

更多说明见 `shop/萌宠优选_后端交接包/README.md` 与 `RUNBOOK.md`。

## Git 说明

- 分支：`main`（本地仓库，暂无远程）
- 只跟踪 `shop/萌宠优选_后端交接包/` 与本说明等必要文件
- 本机环境与辅助文件不入库：`dev-redis/`、`msi-logs/`、`mysql-backup/`、`release/`、`ch09_png/`、课程笔记、安装日志等
- `node_modules/`、`target/`、`*.jar`、`.env*`、`config/backend.env`、日志与备份由 `.gitignore` 排除
