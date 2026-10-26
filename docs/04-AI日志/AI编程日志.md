# AI 编程日志

> 项目：萌宠优选 · 宠物商城系统　｜　记录要求：每人每天 2–3 条，当天记录，不后补
> 字段：编号 / 日期 / 阶段 / 工具与模型 / Prompt 原文 / 生成摘要 / 是否采纳 / 修改理由 / 人工修改点 / 测试验证结果与证据
> 说明：本文件先记录 P1 阶段"数据库表结构设计与执行"的 2 条真实记录；后续按里程碑追加。

---

## AI-001 生成 `pet_mall` 建库建表与种子数据脚本

| 字段 | 内容 |
|---|---|
| 编号 | AI-001 |
| 日期 | 2026-10-19 |
| 阶段 | P1 数据与契约（D3–D4） |
| 工具与模型 | DeepSeek Harness（deepseek-flash） |
| Prompt 原文 | "根据需求文档和设计文档，设计表结构并执行sql"；上下文文件：`docs/01-需求文档/宠物商城系统_企业级需求文档_v2.0.md`（§7 数据需求、§7.7 初始化数据要求）、`docs/02-设计文档/宠物商城系统_企业级设计文档_v1.0.md`（§6 数据库设计、§6.4 建表 DDL、§6.8 初始化数据）、`shop/RuoYi-Vue-master/sql/ry_20260417.sql`、`shop/RuoYi-Vue-master/sql/quartz.sql` |
| 生成摘要 | 生成 `db/01_base.sql`（建库 + 若依 31 张系统表，UTF-8、关闭外键检查）、`db/02_pet_mall.sql`（14 张 `pet_*` 业务表 DDL、9 个唯一键、5 个 CHECK、45 个索引）、`db/03_seed.sql`（5 个演示账号、2 商家/审核员角色、26 条商城菜单、8 个 `mall.*` 参数、8 分类、12 商品、24 SKU、3 宠物档案、3 地址、2 演示订单、27 条库存流水）、`db/rollback.sql`、`db/verify.sql` |
| 是否采纳 | 采纳（主体结构与设计文档 §6.4 一致） |
| 修改理由 | ① 设计文档 `pet_member_pet.species CHAR(2)` 与实际枚举 `CAT/DOG/SMALL` 冲突，严格模式下插入报 ERROR 1406，修正为 `VARCHAR(10)`；② 设计未给出 `merchant1` 与 `merchant_id=9001` 的绑定落点，补充 `sys_dept.dept_id=9001` 作为商家主体；③ 若依 `sys_config` 无 `config_key` 唯一索引，seed 改为 `DELETE ... LIKE 'mall.%'` + 显式 `config_id` 保证幂等 |
| 人工修改点 | 审阅 14 张表字段/索引/注释与设计文档逐项对照；修正 `species` 类型；补充商家部门与 RBAC 菜单授权；确认种子数据量满足需求 §7.7 |
| 测试验证结果 | `db/verify.sql` 中 A/B/C 共 35 项判定全部 PASS；约束实测负库存/0 价格/数量 0/体重 200/负应付均报 `ERROR 3819`，重复用户名/幂等键/流水组合键均报 `ERROR 1062`；BCrypt 5 个账号 `matches` 全部 MATCH |
| 证据路径 | `db/evidence/verify_result.txt`、`db/evidence/constraint_test_result.txt`、`docs/02-设计文档/数据库表结构设计与执行记录_v1.0.md` |

---

## AI-002 执行 SQL、幂等/回滚演练与一致性校验

| 字段 | 内容 |
|---|---|
| 编号 | AI-002 |
| 日期 | 2026-10-19 |
| 阶段 | P1 数据与契约（D3–D4） |
| 工具与模型 | DeepSeek Harness（deepseek-flash） |
| Prompt 原文 | 延续 AI-001："按 01→02→03 顺序在 MySQL 8.0.46 执行，并验证表数量、种子数据、约束与对账；确认脚本可重复执行、可回滚" |
| 生成摘要 | 生成执行与校验命令；使用 `--default-character-set=utf8mb4` 导入；生成 `db/verify.sql`（结构/数据量/一致性三组校验）与证据文件 |
| 是否采纳 | 采纳，并按实测结果修正一处 DDL |
| 修改理由 | 首次执行 `03_seed.sql` 在 `pet_member_pet` 插入时报 `ERROR 1406: Data too long for column 'species'`，定位为设计文档 `CHAR(2)` 与枚举值不匹配；修正 `02_pet_mall.sql` 后重跑成功 |
| 人工修改点 | 复核 `CHAR(2)→VARCHAR(10)` 的必要性；确认 `AUTO_INCREMENT`、中文注释、字符集；将执行证据归档到 `db/evidence/` |
| 测试验证结果 | `pet_mall` 45 张表（31 若依 + 14 业务）；`shop` 库保持 31 张未受影响；`03_seed.sql` 重复执行成功（幂等）；`rollback.sql` 后 45→31，重建后 31→45；库存对账/订单金额/支付对账差异均为 0 |
| 证据路径 | `db/evidence/table_list.txt`、`db/evidence/key_data_snapshot.txt`、`db/README.md` |

---

## AI-003 业务库切换：由 `pet_mall` 调整为 `shop` 并迁移业务表

| 字段 | 内容 |
|---|---|
| 编号 | AI-003 |
| 日期 | 2026-10-19 |
| 阶段 | P1 数据与契约（D3–D4） |
| 工具与模型 | DeepSeek Harness（deepseek-flash） |
| Prompt 原文 | "我要用的不是那个shop的库吗" → 确认选择"B. 改用 shop，把业务表导进去" |
| 生成摘要 | 将 `01_base.sql`/`02_pet_mall.sql`/`03_seed.sql`/`verify.sql`/`rollback.sql`/`verify_constraints.sql` 的目标库由 `pet_mall` 改为 `shop`；对 `shop` 执行 02+03（跳过 01，复用已有 31 张若依表）；同步修改一键脚本默认库与说明；把需求文档、设计文档、环境说明、规划稿中的 `pet_mall` 表述统一改为 `shop`，并重新生成需求文档 DOCX；刷新 `db/evidence/` |
| 是否采纳 | 采纳 |
| 修改理由 | 后端 `application-druid.yml` 已配置 `jdbc:mysql://localhost:3306/shop`，且 `shop` 已有可登录的若依基座；按项目确认改用 `shop`，避免改连接串，同时保留 `pet_mall` 作参考库 |
| 人工修改点 | 逐文件核对 `USE shop` 与表数量；确认不执行 01（避免重建 shop 系统表）；校验 shop 由 31 张增至 45 张；更新 README/执行记录/一键脚本 |
| 测试验证结果 | `shop`：45 张表（31 若依 + 14 业务）；`verify.sql` A/B/C 35 项全部 PASS；约束实测 5×`ERROR 3819`、3×`ERROR 1062`、T09=1/T10=0；02+03 连续两次执行均成功（幂等）；一键脚本 `-Action Status / Verify / VerifyConstraints` 均正常；DOCX 文本核对：`shop` 出现 3 处、`pet_mall` 仅剩脚本文件名 2 处 |
| 证据路径 | `db/evidence/verify_result.txt`、`db/evidence/constraint_test_result.txt`、`db/README.md`、`docs/02-设计文档/数据库表结构设计与执行记录_v1.0.md` §2.1 |

---

## AI-004 制作"后端交接包"（源码 + 数据库 + 文档 + AI 配置说明）

| 字段 | 内容 |
|---|---|
| 编号 | AI-004 |
| 日期 | 2026-10-19 |
| 阶段 | P1 数据与契约（交接准备） |
| 工具与模型 | DeepSeek Harness（deepseek-flash） |
| Prompt 原文 | "帮我把他需要用到的所有东西制作成一个压缩文件，并在里面添加各种说明（他已经安装好了前期的各种东西），只要读取说明里的东西，ai就能配置好和我这边一样的数据库等环境" |
| 生成摘要 | 生成 `00-START-HERE-AI-环境配置说明.md`（给 AI 的执行协议、变量约定、数据库三种场景、后端配置、构建启动、验收、故障排查、禁止操作、报告模板）；生成只读预检脚本 `setup/env-check.ps1`（探测 JDK17/Maven/MySQL/Redis/Node/端口/项目文件，输出 `env-report.txt`）；按 `backend/`、`admin-ui/`、`db/`、`docs/`、`scripts/`、`setup/` 组织并打包为 `release/萌宠优选_后端交接包_20261019.zip`（691 个条目，9.39 MB），附 SHA256 |
| 是否采纳 | 采纳 |
| 修改理由 | 排除 `node_modules/`、`target/`、`.idea/`、`dev-redis/`、历史版本文档与本机数据库文件，避免包体过大或把源机器路径/密码带进去；数据库通过 SQL 脚本重建，保证接手机器得到同一结构 |
| 人工修改点 | 修正预检脚本中"单元素结果被当成字符串索引"的缺陷；端口探测改为 `Get-NetTCPConnection` + TCP 回退；Redis `PING` 失败时回退端口探测；补充同机/异机数据库协作模式与"不要共用同一个库"的说明 |
| 测试验证结果 | 解压包后运行 `setup/env-check.ps1` 成功（exit 0）；正确识别 `backend` 目录、MySQL `shop` 45 张表 / 14 张业务表；ZIP 中文文件名保持正常；包内无 `node_modules`/`target`/`.git`；SHA256 已生成 |
| 证据路径 | `release/萌宠优选_后端交接包_20261019.zip`、`release/萌宠优选_后端交接包_20261019.zip.sha256.txt`、`docs/02-设计文档/00-给AI的配置说明_后端交接包.md`、`setup/env-check.ps1` |

---

## 记录模板（后续追加）

| 字段 | 内容 |
|---|---|
| 编号 | AI-XXX |
| 日期 | YYYY-MM-DD |
| 阶段 | P0–P7 |
| 工具与模型 | 工具名 + 模型版本 |
| Prompt 原文 | 完整 Prompt（含 `@` 文件引用） |
| 生成摘要 | 生成了什么、落在哪些文件 |
| 是否采纳 | 采纳 / 部分采纳 / 拒绝 |
| 修改理由 | 拒绝或修改的原因 |
| 人工修改点 | 具体改了哪一行/哪个设计 |
| 测试验证结果 | 命令、结果、截图路径 |
| 证据路径 | 代码、测试、截图 |
