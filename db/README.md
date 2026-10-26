# db — 数据库脚本与执行说明

> 项目：萌宠优选 · 宠物商城系统　｜　数据库：MySQL 8.0 单库 `shop`
> 依据：`docs/01-需求文档/宠物商城系统_企业级需求文档_v2.0.md`（§7 数据需求）、`docs/02-设计文档/宠物商城系统_企业级设计文档_v1.0.md`（§6 数据库设计）
> 最近执行：2026-10-19，MySQL 8.0.46；文档库名统一为 `shop` 后再次执行 02 + 03 复核通过，执行结果见 `db/evidence/verify_result.txt`
>
> **库名说明**：设计文档 ADR-03 原按 `pet_mall` 编写，现已同步修订为 `shop`；因后端 `application-druid.yml` 已指向 `shop`，经项目确认统一使用 **`shop`** 库——复用其已有 31 张若依系统表，仅导入 14 张业务表。`pet_mall` 为按原设计执行后留存的参考库，确认不需要后可执行 `DROP DATABASE pet_mall;` 删除。

## 1. 脚本清单与执行顺序

| 顺序 | 脚本 | 内容 | 可重复执行 | 说明 |
|---|---|---|---|---|
| 1 | `01_base.sql` | 若依基座 31 张表（`ry_20260417.sql` 20 张 + `quartz.sql` 11 张）+ 建库 `shop` | 是（先 drop 再建） | 保持若依原始 DDL/DML 不变，仅补 `SET NAMES`、`FOREIGN_KEY_CHECKS=0`、库名；**shop 已有若依表时跳过本脚本** |
| 2 | `02_pet_mall.sql` | 14 张 `pet_*` 业务表（DDL/索引/CHECK/注释） | 是（先 drop 再建） | 与设计文档 §6.4 一一对应 |
| 3 | `03_seed.sql` | 演示账号、RBAC、系统参数、分类/商品/SKU、宠物档案/地址、演示订单与库存流水 | 是（先 DELETE 再插入） | 仅演示/测试环境；会重置 `pet_*` 业务数据 |
| — | `verify.sql` | 只读校验：表数量、种子数据量、约束/索引、库存与支付对账 | 是 | 输出 `PASS/FAIL`，全 PASS 即通过 |
| — | `verify_constraints.sql` | 约束与条件扣减实测（预期报错，事务回滚不污染数据） | 是 | 验证 `ERROR 3819/1062` 与影响行数 1/0 |
| — | `rollback.sql` | 仅 DROP 14 张 `pet_*` 表，保留若依系统表 | 是 | 保留系统表与账号 |
| — | `04_fix_menu_route_name.sql` | 修复 R-01：给商家菜单 3201/3202 补全局唯一 `route_name`（`MerchantItems`/`MerchantOrders`） | 是（幂等 UPDATE） | 管理端与商家端 `items`/`orders` 路由同名会让 admin 的 `/mall/items`、`/mall/orders` 被覆盖成 404；**存量库执行一次，重跑 `03_seed.sql` 后无需再执行（seed 已内置）** |

### 一键脚本（推荐，Windows 双击）

双击 **`scripts/宠物商城数据库.bat`**，按菜单选择：

```
1  初始化/重建（01 → 02 → 03，重置整库）
2  仅重置演示数据（03_seed.sql）
3  自动校验（verify.sql，只读）
4  约束/防超卖实测（verify_constraints.sql）
5  回滚业务表（rollback.sql）
6  查看当前状态
0  退出
```

> 菜单 1 会**重建若依系统表**；`shop` 已有若依表、只想补商城业务表时，不要用菜单 1，改为手工执行 `02_pet_mall.sql` + `03_seed.sql`（当前库已导入完成，日常用菜单 2 重置演示数据即可）。

也可命令行执行（脚本自动定位 `mysql.exe`，密码从 `config/backend.env` 读取或由 `-RootPassword` 传入）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\petmall-db.ps1 -Action Status
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\petmall-db.ps1 -Action Verify
# 推荐直接使用新脚本（自动备份、按库状态选择 01/02/03）：
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -RootPassword '你的密码'
# 旧脚本仍可用：
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\petmall-db.ps1 -Action Init -RootPassword '你的密码'
```

### 手工执行命令（Windows / PowerShell）

> `shop` 已有 31 张若依表时，**跳过第 1 条 `01_base.sql`**，只执行 `02`、`03`（当前环境即如此，已执行完成）。

```powershell
$env:MYSQL_PWD = '<root 密码>'
$mysql = 'C:\dev\mysql-8.0.46-winx64\bin\mysql.exe'
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/01_base.sql"
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/02_pet_mall.sql"
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/03_seed.sql"
& $mysql -uroot --default-character-set=utf8mb4 -t -e "source $PWD/db/verify.sql"
Remove-Item Env:MYSQL_PWD
```

> 必须带 `--default-character-set=utf8mb4`，否则中文注释/数据在 Windows 控制台可能乱码。
> `source` 内的路径需使用 `/` 分隔（或在 Git Bash 中执行 `mysql ... < db/01_base.sql`）。

## 2. 数据库对象概览

| 分类 | 数量 | 说明 |
|---|---|---|
| `pet_*` 业务表 | 14 | 会员、宠物档案、地址、分类、商品、SKU、图片、审核留痕、购物车、订单、订单明细、支付、库存流水、站内消息 |
| `sys_*` / `gen_*` | 20 | 若依 RBAC、字典、参数、日志、代码生成 |
| `qrtz_*` | 11 | Quartz 调度表（超时关单与自动确认收货任务使用） |
| 合计 | 45 | `information_schema.tables` |

- 字符集/排序规则：`utf8mb4` / `utf8mb4_general_ci`（业务表），InnoDB。
- 金额：`DECIMAL(10,2)`；库存：`INT` + `CHECK (stock >= 0)`；不建物理外键（设计 DB-06）。
- 业务表唯一键 9 个、CHECK 约束 5 个，明细见 `db/evidence/structure_indexes.txt`、`structure_checks.txt`。

## 3. 演示账号（交付前请修改）

| 账号 | 域 | 密码 | 角色/说明 |
|---|---|---|---|
| `admin` | 后台 `sys_user` | `admin123` | 超级管理员（若依基座初始化） |
| `merchant1` | 后台 `sys_user` | `merchant123` | 商家；`sys_user.dept_id = merchant_id = 9001` |
| `reviewer` | 后台 `sys_user` | `reviewer123` | 审核员：`mall:item:audit`、`mall:audit:list` |
| `member1` | 前台 `pet_member` | `member123` | 2 个宠物档案、2 个地址、2 张演示订单 |
| `member2` | 前台 `pet_member` | `member123` | 1 个宠物档案、1 个地址，用于越权隔离演示 |

> 密码均为 BCrypt（强度 10）哈希，已用 Spring Security `BCryptPasswordEncoder.matches` 逐个验证通过（见 `docs/02-设计文档/数据库表结构设计与执行记录_v1.0.md`）。

## 4. 种子数据清单（需求 §7.7 / 设计 §6.8）

| 数据 | 数量 | 说明 |
|---|---|---|
| 会员 | 2 | `member1`、`member2` |
| 宠物档案 | 3 | member1：幼猫「奶糖」/ 成犬「豆包」；member2：成猫「橘子」 |
| 收货地址 | 3 | member1 两个（含默认）、member2 一个 |
| 分类 | 8 | 4 个一级（猫粮/狗粮/零食/用品与保健）+ 4 个二级（猫主粮/犬主粮/零食罐头/清洁与保健） |
| 商品 SPU | 12 | 覆盖猫/犬/小宠、幼年/成体/老年、低中高价格段；1 个待审、1 个驳回 |
| SKU | 24 | 每商品 1–3 个规格；`CAT-NETEASE-18` 库存 1（防超卖演示）、`DOG-WP-100` 库存 0（售罄演示） |
| 商品图片 | 12 | 占位路径，后续由后台上传替换 |
| 审核留痕 | 11 | 10 条通过 + 1 条驳回（item 12） |
| 演示订单 | 2 | `PET202610190900000001` 待付款（超时关单演示）；`PET202610160900000002` 已完成（详情演示） |
| 订单明细 / 支付 | 3 / 1 | 已完成订单含成功支付记录（幂等键唯一） |
| 库存流水 | 27 | 24 条 `ADJUST` 初始库存 + 3 条 `DEDUCT`；满足 `Σchange_qty = 当前库存` |
| 商城菜单 / 角色 | 27 / 2 | 商城管理 + 商家中心菜单树；商家、审核员角色与授权 |
| 系统参数 | 8 | `mall.pay-timeout-minutes`、`mall.freight-fee` 等，见 `03_seed.sql` §2 |
| 购物车 / 站内消息 | 2 / 2 | 可选演示数据，便于购物车与消息中心联调 |

## 5. 校验与证据

执行 `verify.sql` 的 37 项检查中，A/B/C 共 35 项判定全部 `PASS`（D 组 2 项为索引/表数量统计），输出存档于 `db/evidence/verify_result.txt`，关键结论：

- 45 张表（31 若依 + 14 业务）、14 张业务表全部 `utf8mb4_general_ci`、表注释完整；
- 9 个业务唯一键、5 个 CHECK 约束、45 个索引与设计文档一致；
- 库存对账、订单金额自洽、支付与订单对账、明细金额、`price_min` 冗余一致性均为 0 差异；
- 待付款订单 `expire_at` 未过期（种子导入后 10 分钟内可直接演示超时关单；超过支付时限后该检查会自然显示 FAIL，重跑 `03_seed.sql` 即可重置）；
- 约束实测：负库存、0 价格、购物车数量 0、体重 200kg、负应付金额均报 `ERROR 3819`；重复用户名/幂等键/库存流水组合键均报 `ERROR 1062`；条件扣减「库存 1 扣 2 次」影响行数为 1 / 0（见 `db/evidence/constraint_test_result.txt`）。

证据文件：

```
db/evidence/
├─ verify_result.txt             # verify.sql 全量输出（35 项判定 PASS + 2 项统计）
├─ constraint_test_result.txt    # 约束与条件扣减实测（预期报错）
├─ table_list.txt                # 45 张表清单
├─ structure_columns.txt         # 14 张业务表字段清单
├─ structure_indexes.txt         # 索引清单
├─ structure_checks.txt          # CHECK 约束清单
├─ show_create_tables.txt        # SHOW CREATE TABLE 全量
└─ key_data_snapshot.txt         # 演示订单与每 SKU 库存对账快照
```

## 6. 回滚

```powershell
& $mysql -uroot --default-character-set=utf8mb4 -e "source $PWD/db/rollback.sql"
```

回滚后表数量由 45 降为 31（仅保留若依基座）。如需同时清理商城 RBAC/参数，按 `rollback.sql` 末尾注释执行。生产环境禁止用 `02_pet_mall.sql` drop 重建，表结构变更必须走 `ALTER` 迁移并先备份。

## 7. 与设计文档的差异

| 项 | 文档定义 | 实际实现 | 原因 |
|---|---|---|---|
| 业务库名 | 设计 ADR-03 原为 `pet_mall`（文档已同步修订为 `shop`） | **`shop`** | 后端 `application-druid.yml` 已指向 `shop`，经项目确认统一用 `shop`（复用其 31 张若依表，仅导入 14 张业务表）；`pet_mall` 保留为参考库 |
| `pet_member_pet.species` | `CHAR(2)`，取值 `CAT/DOG/SMALL` | `VARCHAR(10)` | `CHAR(2)` 无法容纳 `DOG`(3)/`SMALL`(5)，严格模式下插入失败；按枚举语义修正 |
| 商家与 `merchant_id` 绑定 | “`merchant1` 绑定 `merchant_id=9001`”，未指定落点 | 新增 `sys_dept.dept_id=9001`，`sys_user.dept_id=9001` | 复用若依部门作为商家主体，`pet_item.merchant_id=9001` 与之对应 |
| 订单状态 | 设计 §4.3.1 为 9 状态（0–8） | 采用 0–8；演示数据用 0/4 | 以需求/设计 §4.3.1 为准（早期规划稿的 6 状态已废弃） |
| 初始化数据 | 设计 §6.8 未列购物车/消息/图片/审核留痕 | 额外写入 2/2/12/11 条 | 便于后续页面联调；属于可选演示数据，已在本文件标注 |

> 已同步修订需求文档 §7.4.2/§2.7、设计文档 §6.4.2/ADR-03/§6/§11 与规划稿，库名统一为 `shop`；需求文档 DOCX 已重新生成。
