# scripts 与 setup 的分工

本仓库有两套脚本，用途不同，不要混用：

| 目录 | 定位 | 典型文件 | 什么时候用 |
|---|---|---|---|
| `setup/` | **运行期**：环境预检、建库、构建、启动、停止、冒烟 | `env-check.ps1`、`init-db.ps1`、`build-ui.ps1`、`start-all.ps1`、`start-admin.ps1`、`smoke-test.ps1` | 已经装好 MySQL/Redis/JDK/Node，只想把系统跑起来 |
| `scripts/` | **装机期（Windows 本机）**：安装 MySQL 实例、安装 Redis 服务、手工建库导入 | `Init-MySqlInstance.ps1`、`redis-install.ps1`、`petmall-db.ps1` | 新机器上还没有数据库/缓存服务，需要先装环境 |

## 常用入口

```powershell
# 运行（推荐）
.\check-env.bat          # 环境预检，报告写入 setup\env-report.txt
.\init-db.bat            # 首次建库（Auto：空库 01→02→03，已有库走增量）
.\start-all.bat          # 用户端 81 + 管理端 80（自动构建前端、自动起后端）
.\smoke-test.bat         # 接口 + 权限冒烟验收
.\stop-backend.bat       # 停止后端（只停本项目 ruoyi-admin.jar）

# 仅管理端 / 仅用户端
.\start-admin-runtime.bat
.\start-mall.bat

# 前端单独构建（自动 npm ci + 生成 .env.* + 增量构建）
powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Both
```

## 装机期脚本（新机器首次）

| 脚本 | 作用 |
|---|---|
| `MySQL初始化.bat` → `mysql-init-stage1.ps1` | 以管理员权限下载/安装 MySQL 8 并初始化实例 |
| `Init-MySqlInstance.ps1` | 配置 MySQL 实例（端口、字符集、root 密码） |
| `建库导入.bat` → `init-ruoyi-db.ps1` | 建 `shop` 库并导入若依表 |
| `宠物商城数据库.bat` → `petmall-db.ps1` | 菜单式建库/校验（db/README 中引用） |
| `Redis安装.bat` → `redis-install.ps1` | 安装 Redis 并注册为 Windows 服务 |

> 已经有 MySQL 8 与 Redis 7 的机器**不需要**执行上表，直接用 `setup/` 的入口即可。

## scripts/srs

`gen_figures.py` 提供绘图基础函数，被 `gen_figures_v2.py`（SRS V2 图）与 `gen_design_figures.py`（设计文档图）导入复用；`md_to_docx.py`、`check_md.py` 用于文档导出与校验。它们只在写文档时使用，与系统运行无关，需要 Python + Pillow + python-docx。
