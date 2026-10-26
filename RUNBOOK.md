# 萌宠优选 · 后端运行与验收手册（RUNBOOK）

## 2026-10-27 修复版启动

日常双击 `start-mall.bat`（`start-user-ui.bat` 同入口），访问 http://127.0.0.1:81/ 。入口启动已安装的本机 MySQL/Redis 服务或 PetMall 计划任务，等待 `/api/health` 数据库与缓存检查通过，再启动用户端。后端源码变化会自动构建，先安全停止本项目 JAR 进程以避免 Windows 锁文件。运行包已有构建，无须安装前端依赖。

管理端生产构建用 `start-admin-runtime.bat` 在 http://127.0.0.1:80/ 启动，先启动商城后端。管理端重新构建先复制 `.env.example` 为 `.env.production`，设置 `VITE_APP_ENV=production`、`VITE_APP_BASE_API=/prod-api`。本机配置均不提交。

换机先填写 `config/backend.env` 并安装运行环境。日常启动不要执行 `03_seed.sql`；本轮无表结构变更或数据重置。查看 `logs/console.log`、`logs/user-ui.err.log`，或 http://127.0.0.1:8080/api/health 排错。本地 MySQL 8 认证参数已通过配置传递，无须手写 JDBC 环境变量。

详情见 `docs/修复记录-v1.1.0.md` 和 `user-ui/README.md`。以下保留原交接基线，历史验收数字不代表本轮结果。

> 适用：Windows 10/11 + PowerShell 5.1+　｜　版本：v2.0　｜　更新：2026-10-19
>
> 本文是 `README.md` 的详细版，覆盖换机、数据库初始化、构建、启动、验收、重置和排错。

## 1. 交付基线

| 项 | 值 |
|---|---|
| 后端框架 | RuoYi 3.9.2 / Spring Boot 4.1.0 |
| 编译目标 | Java 17 |
| 模块 | `ruoyi-admin`、`ruoyi-common`、`ruoyi-framework`、`ruoyi-system`、`ruoyi-quartz`、`ruoyi-generator`、`ruoyi-mall` |
| 数据库 | MySQL 8.0，库 `shop`，45 张表（31 若依 + 14 业务） |
| 缓存/会话 | Redis 7，默认 `127.0.0.1:6379` |
| 默认端口 | 8080 |
| 构建产物 | `dist\ruoyi-admin.jar`（约 86 MB） |
| 数据库校验 | `db\verify.sql`，35 项 PASS |
| 冒烟验收 | `setup\smoke-test.ps1`，30 项 PASS |

## 2. 换机前置条件与安装

### 2.1 JDK 17+

任选 Temurin、Microsoft OpenJDK、Oracle JDK 17/21。安装后：

```powershell
java -version
# 期望包含 17.x 或更高
```

若机器有多个 JDK，在 `config\backend.env` 写：

```ini
JAVA_HOME=C:\Program Files\Java\jdk-17
```

> 本包 JAR 的编译目标是 17；用 JDK 17/21/25 运行均可。不要用 JDK 8。

### 2.2 MySQL 8.0

安装时设置 root 密码，确认服务名（常见 `MySQL80`）：

```powershell
Get-Service MySQL80
mysql -uroot -p -e "SELECT VERSION();"
```

若 `mysql` 不在 PATH，在 `config\backend.env` 写：

```ini
MYSQL_HOME=C:\Program Files\MySQL\MySQL Server 8.0
# 或
MYSQL_EXE=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe
```

### 2.3 Redis 7

Windows 可使用 Redis 兼容发行版、WSL 或 Docker，只要本机 6379 可连：

```powershell
redis-cli ping
# PONG
```

有密码时：

```ini
REDIS_PASSWORD=你的Redis密码
```

## 3. 数据库初始化

### 3.1 自动模式（推荐）

```powershell
cd C:\petmall
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1
```

脚本根据 `shop` 当前状态选择：

| 表数 / `pet_*` | 动作 | 是否覆盖 |
|---|---|---|
| 0 / 0 | `01 → 02 → 03` | 新库，无数据可覆盖 |
| 31 / 0 | `02 → 03` | 保留若依系统表 |
| 45 / 14 | 跳过 | 不覆盖 |
| 其他 | 退出 | 需人工确认 |

### 3.2 显式模式

```powershell
# 查看状态（只读）
powershell -File .\setup\init-db.ps1 -Action Status -RootPassword '<密码>'

# 只跑 verify.sql（只读）
powershell -File .\setup\init-db.ps1 -Action Verify -RootPassword '<密码>'

# 只重置演示数据（会备份到 backup\）
powershell -File .\setup\init-db.ps1 -Action Seed -Force -RootPassword '<密码>'

# 仅补业务表（已有 31 张若依表时）
powershell -File .\setup\init-db.ps1 -Action Business -Force -RootPassword '<密码>'

# 整库重建（会备份，再执行 01→02→03）
powershell -File .\setup\init-db.ps1 -Action Fresh -Force -RootPassword '<密码>'
```

> `-Force` 是破坏性操作的确认开关。没有 `-Force` 时，`Fresh/Business/Seed` 会拒绝执行。
> `-NoBackup` 可跳过 `mysqldump`，只建议在空库/演示库使用。

### 3.3 手工执行（不使用脚本时）

```powershell
$env:MYSQL_PWD = '<root密码>'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
cd C:\petmall
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/01_base.sql"
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/02_pet_mall.sql"
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/03_seed.sql"
& $mysql -uroot --default-character-set=utf8mb4 -t -e "source $PWD/db/verify.sql"
Remove-Item Env:MYSQL_PWD
```

> `01_base.sql` 只适用于全新库/允许重建的库；已有 31 张若依表时只执行 `02 + 03`。

### 3.4 种子数据与演示时限

- 8 分类、12 商品、24 SKU、3 宠物档案、3 地址、2 订单、27 条库存流水；
- 待付款订单 `expire_at = 导入时刻 + 10 分钟`；
- `verify.sql` 的 C08 会检查未过期；超过 10 分钟自然 FAIL，重新执行 `03_seed.sql` 即可。

## 4. 配置项

`config\backend.env`（从 `backend.env.example` 复制）由脚本读取并注入 Spring 环境变量。优先级：命令行参数 > `backend.env` > 默认值。

| 变量 | 默认 | 说明 |
|---|---|---|
| `DB_HOST` / `DB_PORT` | `127.0.0.1` / `3306` | MySQL 地址 |
| `DB_NAME` | `shop` | 数据库名；SQL 脚本固定使用 `shop` |
| `DB_USERNAME` / `DB_PASSWORD` | `root` / 空 | 数据库账号 |
| `DB_USE_SSL` | `false` | 本机无证书保持 false |
| `REDIS_HOST` / `REDIS_PORT` | `127.0.0.1` / `6379` | Redis 地址 |
| `REDIS_DATABASE` | `0` | Redis 库号 |
| `REDIS_PASSWORD` | 空 | Redis 密码 |
| `SERVER_PORT` | `8080` | 后端 HTTP 端口 |
| `RUOYI_PROFILE` | `data/uploadPath` | 上传目录，相对包根目录 |
| `LOG_PATH` | `logs` | 日志目录 |
| `LOG_LEVEL` | `info` | `debug` 可看更多业务日志 |
| `TOKEN_SECRET` | 演示值 | 正式环境必须改 |
| `DRUID_USERNAME` / `DRUID_PASSWORD` | `ruoyi` / `123456` | Druid 控制台 |


## 5. 构建与启动

### 5.1 直接运行已构建 JAR（推荐）

```powershell
cd C:\petmall
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -SkipBuild
```

脚本会：

1. 从 `config\backend.env` 读取配置；
2. 自动查找 JDK 17+；
3. 优先使用 `dist\ruoyi-admin.jar`；
4. 创建 `data\uploadPath`、`logs`、`run`；
5. 后台启动并轮询 `/captchaImage`，最多 120 秒；
6. 将 PID 写入 `run\backend.pid`。

指定端口/密码：

```powershell
.\setup\start-backend.ps1 -Port 8081 -MySqlPassword '<密码>' -SkipBuild
```

前台运行（调试时看控制台）：

```powershell
.\setup\start-backend.ps1 -Foreground -SkipBuild
```

### 5.2 从源码构建

需要 Maven 3.9+：

```powershell
cd C:\petmall\backend
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
mvn -pl ruoyi-admin -am -DskipTests package
```

产物：`backend\ruoyi-admin\target\ruoyi-admin.jar`。启动脚本检测不到 `dist` JAR 时会自动构建。

### 5.3 停止与端口

```powershell
.\setup\stop-backend.ps1
# 或
stop-backend.bat
```

停止脚本只停止 PID 文件中、且命令行包含 `ruoyi-admin.jar` 的进程，避免误杀其他 Java 程序。

## 6. 验收

### 6.1 一键冒烟（只读）

```powershell
cd C:\petmall
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\smoke-test.ps1
```

覆盖 30 项：

- 公开：分类、推荐、商品列表/详情；
- 会员：登录、`/me`、宠物、地址、订单、购物车、无 Token 401；
- 后台：管理员登录、`getInfo`、商品/分类/会员/订单/库存/看板；
- 商家：商品列表、禁止访问管理员接口（HTTP 200 + `code=403`）；
- 审核员：待审队列、禁止访问会员/看板（HTTP 200 + `code=403`）；
- 双域隔离：会员 Token 访问后台返回 HTTP 200 + `code=401`。

结果写入 `verify\smoke-result.txt`，同时打印 `PASS/FAIL/SKIP`。

> 冒烟脚本会从 Redis 读取 `captcha_codes:<uuid>`，因此 Redis 必须是后端实际使用的那个库（默认 0）。

### 6.2 手工验证

```powershell
# 验证码
curl.exe http://127.0.0.1:8080/captchaImage

# 公开商品
curl.exe "http://127.0.0.1:8080/api/items?pageNum=1&pageSize=5"

# 会员登录
curl.exe -X POST http://127.0.0.1:8080/api/member/login `
  -H "Content-Type: application/json" `
  -d '{\"username\":\"member1\",\"password\":\"member123\"}'
```

后台登录需要验证码：先从 `/captchaImage` 获取 `uuid` 和图片，再把验证码 `code`、`uuid` 与账号密码 POST 到 `/login`。

### 6.3 验收标准

| 项 | 期望 |
|---|---|
| `init-db.ps1 -Action Verify` | `PASS=35 FAIL=0` |
| `smoke-test.ps1` | `PASS=30 FAIL=0` |
| 启动日志 | `Started RuoYiApplication` |
| Swagger | `/swagger-ui.html` 可打开 |
| 后台登录 | `admin/admin123` 返回 `code=200` + token |
| 会员登录 | `member1/member123` 返回 `code=200` + token |

## 7. 日志与运行数据

| 路径 | 内容 |
|---|---|
| `logs\console.log` | 启动/SQL/业务控制台日志 |
| `logs\console.err.log` | JVM 标准错误 |
| `logs\sys-info.log` | 若依 INFO 日志 |
| `logs\sys-error.log` | 若依 ERROR 日志 |
| `run\backend.pid` / `run\backend.port` | 当前后端进程与端口 |
| `data\uploadPath` | 上传文件 |
| `backup\` | `init-db.ps1` 的 mysqldump 备份 |
| `verify\smoke-result.txt` | 最近一次冒烟结果 |

## 8. 排错顺序

1. `setup\env-report.txt` 是否全部满足；
2. MySQL 3306 是否 LISTEN、`SELECT VERSION()` 是否成功；
3. `shop` 是否 45 张表、`pet_*` 是否 14；
4. Redis 6379 是否 PONG、`REDIS_PASSWORD` 是否正确；
5. `dist\ruoyi-admin.jar` 是否存在、是否被解压软件截断；
6. 8080 是否被占用（`Get-NetTCPConnection -LocalPort 8080`）；
7. 看 `logs\console.log` 第一条 `ERROR` / `Caused by`；
8. 看 `logs\console.err.log` 是否有 JDK/内存错误。

| 现象 | 原因/处理 |
|---|---|
| `java -version` 是 1.8 | 设置 `JAVA_HOME` 指向 17+，重开终端 |
| `mvn` 找不到 | 直接运行 `dist` JAR，或安装 Maven 3.9+ |
| `Access denied for user` | `DB_PASSWORD` 错；注意特殊字符不要加引号 |
| `Public Key Retrieval is not allowed` | 保持 `DB_USE_SSL=false`，或给 MySQL 用户配置 caching_sha2 |
| Redis `NOAUTH` | 填写 `REDIS_PASSWORD` |
| 验证码一直错误 | 确认冒烟脚本与后端连接同一个 Redis 库；不要手工复用已消费的 uuid |
| 端口占用 | `SERVER_PORT=8081` 或 `-Port 8081` |
| 中文乱码 | SQL 脚本已带 `utf8mb4`；终端执行 `chcp 65001` |
| 表数不是 45 | 不要手工跳过 `02`；执行 `init-db.ps1 -Action Status` 查看 |
| 想恢复干净演示环境 | `init-db.ps1 -Action Seed -Force`（会备份） |

## 9. 数据重置与备份

| 操作 | 命令 | 影响 |
|---|---|---|
| 查看状态 | `init-db.ps1 -Action Status` | 只读 |
| 校验 | `init-db.ps1 -Action Verify` | 只读 |
| 重置演示数据 | `init-db.ps1 -Action Seed -Force` | 重置 `pet_*`、商城菜单/角色/参数 |
| 补业务表 | `init-db.ps1 -Action Business -Force` | 重建 `pet_*` |
| 整库重建 | `init-db.ps1 -Action Fresh -Force` | 重建 31 张系统表 + 14 张业务表 |
| 回滚业务表 | 手工执行 `db\rollback.sql` | 只删 14 张 `pet_*`，保留系统表 |

默认备份目录 `backup\shop_yyyyMMdd_HHmmss.sql`，由 `mysqldump --single-transaction --routines --triggers` 生成。

## 10. 安全清单（正式部署前）

- [ ] 修改 `admin`、`merchant1`、`reviewer`、`member1/member2` 密码；
- [ ] 修改 `TOKEN_SECRET` 为 32 位以上随机值；
- [ ] 修改 `DRUID_PASSWORD`，或关闭 Druid 控制台；
- [ ] 使用独立的 MySQL 业务账号，不使用 root；
- [ ] Redis 设置密码并限制监听地址；
- [ ] 关闭 `springdoc` 或限制 Swagger 访问；
- [ ] 配置 HTTPS 与反向代理；
- [ ] 不要把 `config\backend.env`、`backup\`、`logs\` 提交 Git；
- [ ] 生产环境禁止执行 `db\01_base.sql`、`02_pet_mall.sql` 的 DROP/CREATE 流程。

## 11. 交付验收清单

- [ ] `check-env.bat` 无阻塞项；
- [ ] `init-db.bat` 完成，`shop` 45 张表；
- [ ] `init-db.ps1 -Action Verify` 35 PASS；
- [ ] `start-backend.bat` 显示“后端已就绪”；
- [ ] `smoke-test.bat` 30 PASS；
- [ ] 浏览器能打开 Swagger；
- [ ] `admin/admin123` 能登录管理端；
- [ ] `member1/member123` 能登录会员端；
- [ ] 已修改所有演示密码/密钥（正式环境）。

对应源码位置：`backend\ruoyi-admin\src\main\resources\application.yml`、`application-druid.yml`。所有值均可用 `${ENV:默认值}` 覆盖，不需要改源码。
