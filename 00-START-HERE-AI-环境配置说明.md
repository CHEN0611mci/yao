# 00 · 给 AI 的后端交接执行说明

> **你是接手本项目的 AI 助手。** 本项目后端已完成，不需要从零开发。你的任务是在当前 Windows 电脑上：
> ① 检查环境 → ② 初始化/确认 `shop` 数据库 → ③ 配置连接 → ④ 启动后端 → ⑤ 验收。
>
> 先读 `README.md` 了解包结构，再按本文执行。遇到阻塞先停下报告，不要猜密码、不要盲目重装。

## 1. 包内关键路径

| 路径 | 用途 |
|---|---|
| `dist\ruoyi-admin.jar` | 已构建后端，可直接运行 |
| `backend\` | RuoYi 3.9.2 多模块源码（含 `ruoyi-mall`） |
| `db\01_base.sql → 02_pet_mall.sql → 03_seed.sql` | 建库/业务表/种子数据 |
| `db\verify.sql` | 35 项只读校验 |
| `config\backend.env.example` | 连接配置模板 |
| `setup\env-check.ps1` | 环境预检（只读） |
| `setup\init-db.ps1` | 数据库初始化/校验/备份 |
| `setup\start-backend.ps1` | 启动（探测 JDK、选择 JAR/构建） |
| `setup\stop-backend.ps1` | 停止 |
| `setup\smoke-test.ps1` | 30 项冒烟验收（只读） |

## 2. 执行协议

1. 先运行 `check-env.bat` 或：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\env-check.ps1
   ```
   读取 `setup\env-report.txt`，不要凭猜测填路径。
2. 只向人类询问：
   - MySQL `root` 密码；
   - `shop` 已有未知数据时，是否允许备份后重建；
   - 是否需要改端口（8080 被占用时）。
3. **不要**对已有 45 张表的 `shop` 执行 `01_base.sql`；不要 `DROP DATABASE shop`。
4. **不要**把密码写入 `docs/`、`db/`、Git；只写 `config\backend.env`（该文件已加入 `.gitignore`）。
5. 每条命令执行后核对输出；失败按 §7 排查，不要连续盲目重试。
6. 最终按 §8 输出交接报告。

## 3. 环境要求

| 项 | 要求 | 检查 |
|---|---|---|
| JDK | 17+（推荐 17/21） | `java -version` |
| MySQL | 8.0，3306 | `Get-Service MySQL80` |
| Redis | 7，6379 | `redis-cli ping` → `PONG` |
| Maven | 可选，源码构建时需要 | `mvn -v` |
| 端口 | 8080（默认） | 被占用时用 8081 |

若 `mysql.exe` 不在 PATH，在 `config\backend.env` 写 `MYSQL_HOME` 或 `MYSQL_EXE`。
若 `java` 不是 17+，写 `JAVA_HOME` 指向 JDK 根目录。

## 4. 数据库

### 4.1 自动初始化（推荐）

```powershell
cd <包根目录>
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1
```

按提示输入 root 密码。脚本自动判断：

| 状态 | 动作 |
|---|---|
| 空库 | `01 → 02 → 03` |
| 31 张若依表 / 0 张 `pet_*` | `02 → 03` |
| 45 张表 / 14 张 `pet_*` | 跳过重建 |
| 其他 | 停止，交人工确认 |

### 4.2 校验

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Verify -RootPassword '<密码>'
```

期望 `PASS=35 FAIL=0`。C08 与待付款订单的 10 分钟时限有关，超时后执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Seed -Force -RootPassword '<密码>'
```

### 4.3 手工场景

- 已有 31 张若依表：只执行 `02_pet_mall.sql`、`03_seed.sql`；
- 已有 45 张表：不要执行 01/02，只跑 `verify.sql`；
- 结构未知：先 `mysqldump` 备份，再让人类确认 `-Action Fresh -Force`。

## 5. 配置后端

复制模板：

```powershell
Copy-Item .\config\backend.env.example .\config\backend.env
notepad .\config\backend.env
```

最少修改：

```ini
DB_PASSWORD=<MySQL root 密码>
SERVER_PORT=8080
```

其他默认值：`DB_HOST=127.0.0.1`、`DB_PORT=3306`、`DB_NAME=shop`、`DB_USE_SSL=false`、`REDIS_HOST=127.0.0.1`、`REDIS_PORT=6379`。

> 不想把密码写文件时，可保持 `DB_PASSWORD=CHANGE_ME`，启动脚本会提示输入。

## 6. 启动与验收

### 6.1 启动

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -SkipBuild
```

或双击 `start-backend.bat`。看到：

```text
[ OK ] 后端已就绪：http://127.0.0.1:8080
```

### 6.2 前端：用户端 + 管理端

```powershell
# 一次启动两端（首次自动 npm ci、生成 admin-ui\.env.production、构建 dist）
.\start-all.bat

# 或只启动一端
.\start-mall.bat                 # 用户端 81（含后端）
.\start-admin-runtime.bat        # 管理端 80（后端未启动时加 -StartBackend）

# 只构建，不启动
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Both
```

| 入口 | 地址 | 说明 |
|---|---|---|
| 用户端 | http://127.0.0.1:81/ | `member1/member123` |
| 管理端 | http://127.0.0.1:80/ | `admin/admin123`，登录需手工输入图形验证码 |
| 管理端反代自检 | http://127.0.0.1:80/prod-api/api/health | 返回 `code=200` 说明 `/prod-api` 已去前缀转发到后端 |

管理端构建配置由脚本维护：`admin-ui\.env.production` 内 `VITE_APP_BASE_API='/prod-api'`、`VITE_APP_ENV='production'`。该文件与 `dist`、`node_modules` 均不入库（`.gitignore` 已排除），换机后由 `build-ui.ps1` 重新生成。

### 6.3 验收

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\smoke-test.ps1
```

期望：`PASS=30 FAIL=0`。结果在 `verify\smoke-result.txt`。

手工检查：

- <http://127.0.0.1:8080/swagger-ui.html>
- <http://127.0.0.1:8080/captchaImage>
- `admin/admin123`、`merchant1/merchant123`、`reviewer/reviewer123`、`member1/member123`

### 6.4 停止

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\stop-backend.ps1
```

## 7. 故障排查

| 现象 | 处理 |
|---|---|
| 未找到 JDK 17+ | 安装 JDK 17/21，设置 `JAVA_HOME` |
| `mvn` 找不到 | 用 `dist\ruoyi-admin.jar`，不需要 Maven |
| MySQL 连接失败 | 检查服务、密码、`DB_USE_SSL=false` |
| Redis 未监听 | 启动 Redis；`redis-cli ping` = `PONG` |
| 验证码错误 | 确认 `REDIS_PASSWORD` 与 Redis 库号；不要复用 uuid |
| 端口占用 | `-Port 8081` 或改 `SERVER_PORT` |
| `Unknown database 'shop'` | 先执行 `init-db.ps1` |
| 启动日志报 Redis | 看 `logs\console.log` 第一条 `Caused by` |
| 表数不对 | `init-db.ps1 -Action Status`，不要手工跳过 02 |

> 若依权限拒绝常见为 **HTTP 200 + body `code:403`**；会员拦截器拒绝为 **HTTP 401 + `code:2001`**。这不是接口 500。

## 8. 最终交接报告模板

```text
【环境】
- OS：
- JDK 路径/版本：
- MySQL 版本/服务/端口：
- Redis 版本/端口：
- Maven（可选）：

【数据库】
- shop 表数：45
- pet_* 表数：14
- verify.sql：35 PASS / 0 FAIL
- 备份路径（如有）：

【后端】
- 启动方式：dist JAR / 源码构建
- 端口：8080
- 启动日志：Started RuoYiApplication
- smoke-test：30 PASS / 0 FAIL
- Swagger：可访问

【未完成/风险】
- ...

【结论】
- 本机已可运行，可否交付：是/否
```

## 9. 禁止操作

- ❌ 对已有数据的 `shop` 直接执行 `01_base.sql`；
- ❌ `DROP DATABASE shop`；
- ❌ 使用 JDK 8 运行；
- ❌ 把 MySQL/Redis 密码写入 `docs/`、`db/` 或提交 Git；
- ❌ 在他人演示时执行 `03_seed.sql`；
- ❌ 修改 `db/*.sql` 表结构来“绕过”问题。

## 10. 相关文档

1. `README.md` — 5 步快速开始；
2. `RUNBOOK.md` — 详细运行/排错/安全清单；
3. `db\README.md` — 数据库脚本与证据；
4. `docs\02-设计文档\后端开发交接说明_v1.0.md` — 工程约定与历史交接；
5. `docs\02-设计文档\数据库表结构设计与执行记录_v1.0.md` — 表结构/约束/种子数据。
