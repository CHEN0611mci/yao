# 萌宠优选 · 宠物商城系统 —— 后端运行交接包

> 版本：v2.0（2026-10-19）　｜　目标：**换一台 Windows 电脑，按本说明即可跑通后端**
>
> 后端源码已完成并通过：Maven 构建成功、数据库 35 项校验 PASS、REST 冒烟 30 项 PASS。

## 1. 这个包能做什么

- 直接运行已构建的 `dist\ruoyi-admin.jar`（**不需要先装 Maven**）；
- 也可用 `backend\` 源码重新构建；
- 自带 `db\01→02→03` 数据库脚本，一键初始化 `shop` 库（45 张表）；
- 自带环境检查、启动、停止、冒烟验收脚本；
- 自带完整需求/设计/数据库文档与演示账号。

## 2. 另一台电脑需要什么

| 软件 | 要求 | 说明 |
|---|---|---|
| Windows | 10/11，PowerShell 5.1+ | 脚本已兼容 |
| JDK | **17 或更高**（推荐 17/21） | 只需 JRE/JDK；必须能执行 `java -version` |
| MySQL | **8.0** | 端口 3306，需知道 root 密码 |
| Redis | **7.x**（或兼容版本） | 端口 6379，登录/Token/验证码依赖 |
| Maven | 3.9.x，**可选** | 只在没有 `dist\ruoyi-admin.jar`、需要源码构建时需要 |
| Node.js | 不需要 | 本包只交后端；管理前端另见 `admin-ui\` |

> 建议解压到 `C:\petmall` 这类**无空格、无特殊字符**的目录；中文路径也能运行，但英文路径排错更简单。

## 3. 五步跑通

### 第 1 步：启动 MySQL 和 Redis

```powershell
# 管理员 PowerShell
Start-Service MySQL80
# Redis 若注册为服务：Start-Service Redis；免安装版用 redis-server.exe 启动
```

确认：

```powershell
mysql -uroot -p -e "SELECT VERSION();"
redis-cli ping        # 期望 PONG
```

### 第 2 步：环境预检

双击 `check-env.bat`，或在包根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\env-check.ps1
```

查看 `setup\env-report.txt`。若未提供 MySQL 密码，数据库连接会显示“跳过”，可下一步再验证。

### 第 3 步：初始化数据库

双击 `init-db.bat`。脚本会提示输入 MySQL root 密码，并自动判断：

| 当前 `shop` 库 | 自动动作 |
|---|---|
| 不存在/空库 | 执行 `01_base.sql → 02_pet_mall.sql → 03_seed.sql` |
| 已有 31 张若依表 | 只执行 `02 → 03`，不动系统表 |
| 已有 45 张表 | 跳过重建，提示已初始化 |
| 结构未知 | **停止**，要求人工确认，避免误删 |

也可以直接执行（密码不写入文件）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -RootPassword '<你的MySQL root密码>'
```

完成后可再执行只读校验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Verify -RootPassword '<密码>'
```

预期：`PASS=35 FAIL=0`。若只有 `C08` FAIL，是待付款订单的 10 分钟演示时限已过，执行一次 `-Action Seed -Force` 重置演示数据即可。

### 第 4 步：填写后端配置

打开 `config\backend.env`（首次运行会自动从 `backend.env.example` 生成）：

```ini
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=shop
DB_USERNAME=root
DB_PASSWORD=你的MySQL密码
DB_USE_SSL=false

REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=

SERVER_PORT=8080
RUOYI_PROFILE=data/uploadPath
LOG_PATH=logs
```

> `backend.env` 含密码，**不要提交 Git、不要发给无关人员**。也可以不填密码，启动脚本会弹窗提示输入。

### 第 5 步：启动并验收

双击 `start-backend.bat`，或执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -SkipBuild
```

看到 `后端已就绪` 后：

- Swagger：<http://localhost:8080/swagger-ui.html>
- 验证码接口：<http://localhost:8080/captchaImage>
- 冒烟验收：双击 `smoke-test.bat`，预期 `PASS=30 FAIL=0`

停止后端：双击 `stop-backend.bat`。

## 4. 演示账号

| 账号 | 密码 | 用途 |
|---|---|---|
| `admin` | `admin123` | 后台超级管理员 |
| `merchant1` | `merchant123` | 商家（`merchant_id=9001`） |
| `reviewer` | `reviewer123` | 审核员（最小权限） |
| `member1` / `member2` | `member123` | 前台会员（隔离演示） |

> 账号仅用于课程演示。正式部署前必须修改密码、`TOKEN_SECRET`、Druid 控制台密码。

## 5. 目录说明

```text
萌宠优选_后端交接包/
├─ README.md                      本文件（快速开始）
├─ RUNBOOK.md                     详细运行/排错/验收手册
├─ 00-START-HERE-AI-环境配置说明.md 给 AI 助手的执行说明
├─ start-backend.bat              一键启动（优先 dist JAR）
├─ stop-backend.bat               一键停止
├─ init-db.bat                    一键初始化/校验数据库
├─ check-env.bat                  一键环境预检
├─ smoke-test.bat                 一键冒烟验收
├─ config/
│  └─ backend.env.example         后端配置模板（复制为 backend.env）
├─ setup/
│  ├─ common.ps1                  公共函数
│  ├─ env-check.ps1               环境预检
│  ├─ init-db.ps1                 数据库初始化/校验/备份
│  ├─ start-backend.ps1           启动（含 JDK 探测、JAR/构建选择）
│  ├─ stop-backend.ps1            停止（按 PID + 命令行校验）
│  └─ smoke-test.ps1              30 项只读冒烟
├─ dist/
│  └─ ruoyi-admin.jar             已构建、可直接运行
├─ backend/                       RuoYi 3.9.2 多模块源码（含 ruoyi-mall）
├─ db/                            01/02/03、verify、rollback、证据
├─ admin-ui/                      RuoYi-Vue3 管理前端源码（可选）
├─ docs/                          需求/设计/数据库/AI 日志
├─ scripts/                       历史数据库工具（新环境优先用 setup）
└─ verify/                        smoke-result.txt 验收结果
```

## 6. 常见问题

| 现象 | 处理 |
|---|---|
| `未找到 JDK 17+` | 安装 JDK 17/21，或在 `config\backend.env` 写 `JAVA_HOME=C:\Program Files\Java\jdk-17` |
| `端口 8080 已被占用` | 改 `SERVER_PORT=8081`，或 `start-backend.ps1 -Port 8081` |
| `MySQL 连接失败` | 检查 MySQL80 服务、root 密码、3306；`DB_USE_SSL=false` |
| `Redis 端口未监听` | 启动 Redis；`redis-cli ping` 必须返回 `PONG` |
| 登录提示验证码错误 | 确认 Redis 正常；冒烟脚本会从 Redis 读取验证码 |
| `Unknown database 'shop'` | 先执行 `init-db.bat` |
| 上传图片失败 | `RUOYI_PROFILE` 目录需可写；脚本会自动创建 |
| 后台接口返回 HTTP 200 但 `code=403` | 若依权限拒绝的正常表现，不是 HTTP 500 |
| 会员接口无 Token 返回 HTTP 401 + `code=2001` | 会员拦截器的正常表现 |
| 商城菜单/权限不对 | 重新执行 `03_seed.sql`（会重置演示数据） |
| 想从头重建 | `init-db.bat -Action Fresh -Force`（会先备份到 `backup\`） |

## 7. 已验证项

- Maven：8 个模块 `BUILD SUCCESS`；
- 数据库：`verify.sql` 35 项 PASS（A/B/C 组）；
- 后端：`/captchaImage`、公开商品、会员登录/档案/地址/订单/购物车；
- 后台：`admin` 登录、`getInfo`、商品/分类/会员/订单/库存/看板；
- 权限：商家不能进后台管理、审核员只能看待审队列、会员 Token 不能访问后台；
- 跨域隔离：会员 Token 访问 `/api/admin/*` 返回 HTTP 200 + `code=401`。

详细验收记录见 `RUNBOOK.md` 与 `verify\smoke-result.txt`。
