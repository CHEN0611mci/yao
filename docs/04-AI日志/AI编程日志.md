# AI 编程日志

> 项目：萌宠优选 · 宠物商城系统　｜　记录要求：每人每天 2–3 条，当天记录，不后补
> 字段：编号 / 日期 / 阶段 / 工具与模型 / Prompt 原文 / 生成摘要 / 是否采纳 / 修改理由 / 人工修改点 / 测试验证结果与证据
> 说明：本文件先记录 P1 阶段"数据库表结构设计与执行"的 2 条真实记录；后续按里程碑追加。
> 补录：AI-010/AI-011 对应 2026-10-19 完成并通过运行验收的 `ruoyi-mall` 后端实现（管理端 / 商家端 / 用户端接口），开发当时未单独记录，于 2026-10-26 按合入源码与验收证据补录；日期字段保留真实开发日期，编号按日志追加顺序编排。

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

## AI-005 生成《管理端（admin-ui）前端详细设计 v1.0》

| 字段 | 内容 |
|---|---|
| 编号 | AI-005 |
| 日期 | 2026-10-26 |
| 阶段 | P2 设计（前端详细设计，管理端） |
| 工具与模型 | DeepSeek Harness（deepseek-flash，Agent Teams：管理端/需求 2 名调研完成、用户端调研按新指令中止，2 名分章撰写，Lead 汇总校核） |
| Prompt 原文 | "目前已经完成了后端的编程，现在根据需求文档和设计文档，完成前端的具体设计文档"；追加约束："先设计管理端的前端"；上下文文件：`docs/01-需求文档/宠物商城系统_企业级需求文档_v2.0.md`、`docs/02-设计文档/宠物商城系统_企业级设计文档_v1.0.md`、`backend/ruoyi-mall/**`（已完成源码）、`db/02_pet_mall.sql`、`db/03_seed.sql`、`admin-ui/**` |
| 生成摘要 | 生成 `docs/02-设计文档/管理端前端详细设计_v1.0.md`（约 3930 行 / 278 KB）：§0 文档信息、§1 概述与范围、§2 总体架构、§3 真实接口契约基线（A1–A24、M1–M11）、§4 菜单/路由/权限（10 个页面组件、24 个 `mall:*` 码）、§5 十个页面逐页设计（每页 9 个子节）、§6 商城专用请求层/公共组件/枚举/校验/上传、§7 关键流程、§8 非功能与测试、§9 实施/联调/DoD/风险，附录 A 需求追溯、B 状态枚举错误码、C 演示数据账号、D 文件清单、E 字段字典、F 自检与裁决。另产出调研底稿（`_research/`）与分章草稿（`_draft/`，成稿后清理） |
| 是否采纳 | 采纳（范围按用户追加要求收敛为管理端；用户端另行设计） |
| 修改理由 | 后端已完成，HLD §5 与实现存在 19 处差异（商家路由、审计日志页、请求层、上传组件、会员详情、审核/上架关系等），故以源码为契约基线；管理端与商家端共用同一基座，需同时覆盖两套菜单与权限 |
| 人工修改点 | ①按追加要求暂停 `user-ui` 调研/写作，删除用户端任务；②补 R-01 同名路由冲突（`Items/Orders`）的 seed 修复 SQL；③将商家类目下拉从"手填 ID"改为匿名 `GET /api/home/categories`；④标注后端定时任务未实现、审核无 `audit_status=0` 条件更新、测试工具未安装等 6 条现状；⑤全量校验 24 个权限码与 `db/03_seed.sql` 一致、文档接口与 Controller 对照、表格列数 0 破损 |
| 测试验证结果 | 无代码可执行（本任务为设计文档）；已做静态校验：24 个 `mall:*` 权限码与 `03_seed.sql` 完全一致；文档中 `/api/admin/**`、`/api/merchant/**`、`/api/upload/**` 路径逐条对照 Controller（示例路径/前缀除外）；无 BOM、代码围栏成对、表格列数一致；10 个页面 × 9 子节齐备；§ 交叉引用无缺失 |
| 证据路径 | `docs/02-设计文档/管理端前端详细设计_v1.0.md`；调研底稿曾位于 `docs/02-设计文档/_research/`（已清理） |

---

## AI-006 按设计文档实现管理端前端 10 个页面与公共底座

| 字段 | 内容 |
|---|---|
| 编号 | AI-006 |
| 日期 | 2026-10-26 |
| 阶段 | P3 前端开发（管理端 `admin-ui`） |
| 工具与模型 | DeepSeek Harness（deepseek-flash，Agent Teams：Lead 1 + 队友 4：`fe-product`/`fe-trade`/`fe-merchant`/`fe-catalog`） |
| Prompt 原文 | "已给出前端设计文档，根据文档完成前端项目的开发"；唯一施工图：`docs/02-设计文档/管理端前端详细设计_v1.0.md`（§3 接口契约、§4 菜单权限、§5 十个页面、§6 请求层/组件/枚举、§9 验收）；约束：不改若依基座（`utils/request.js`、`permission.js`、`router/index.js`、`layout/**`、`main.js`）、不新增依赖、商城接口只经 `mallRequest`、按 `sys_menu.component` 全等建文件 |
| 生成摘要 | 新增 21 个工程文件（+1 自检脚本 +1 DB 补丁）：`utils/mallRequest.js`（商城 `Result` 专用 axios 实例：解包 `data`、`message+PET-xxxx+traceId` 后 6 位、401 只弹一次、429 按 Retry-After）、`utils/mallDict.js`（订单/审核/上下架/SKU/支付/流水/会员/物种/年龄/范围/审计枚举 + `formatMoney/parseSnapshot/buildCategoryMap/dateRangeToParams/maskPhone/maskName/copyText/optionsOf`）、`api/mall/{dashboard,item,category,order,member,stock,auditLog,merchant,upload}.js`（A1–A24、M1–M11，共 32 个函数）、`components/mall/{MallStatusTag,MallMoney,MallImageUpload,CategoryTreeSelect,SkuEditor,ItemFormDrawer,AuditDrawer,OrderDetailDrawer,ShipDialog,StockAdjustDialog}.vue`、`views/mall/**/index.vue` 10 个页面、`admin-ui/scripts/mall-check.mjs` 静态自检、`db/04_fix_menu_route_name.sql`（R-01 补丁：3201/3202 `route_name` 全局唯一化） |
| 是否采纳 | 采纳（页面/权限/接口按设计文档实现；3 处按文档回改，见"人工修改点"） |
| 修改理由 | ①设计文档 §5.8.2 明确库存两接口无分页"不渲染 pagination、不做前端假分页"，队友初版按 §7.7 做了前端 20/页，回改为 `max-height=560` + 「共 N 条」+ 全量渲染；②§5.8.4 要求低库存单元格红色加粗、0 加「缺货」，回改样式口径；③§5.9.4/§5.9.7 要求审计 `businessType/status` 用系统字典 `sys_oper_type/sys_common_status`（`useDict` + `DictTag`），初版用前端常量，已回改并保留原始值兜底；④商家类目下拉按 §5.10.7 R-02 走匿名 `GET /api/home/categories`（商家无 `mall:category:list`，调 admin 接口会 403）；⑤`MallImageUpload` 不复用基座 `ImageUpload`，兼容 `Result.data.{url,fileName}`，表单值统一输出相对路径逗号串；⑥`AuditDrawer`/`OrderDetailDrawer`/`ShipDialog` 在 §6.4 契约外补充 `readonly`/`failed` 事件，用于"查看"只读抽屉与失败后刷新列表（已在交付说明登记） |
| 人工修改点 | Lead 先落地请求层、枚举、API 层与 4 个基础组件（契约先行），再分 4 个互不重叠写域并行页面；对 4 份交付逐项复核：组件 props/emits 跨页一致、`v-hasPermi` 权限码与 seed 24 码一致、日期参数为订单 `startTime/endTime`、审计 `beginTime/endTime` 顶层（禁用 `addDateRange`）、商品/审核页 review 无编辑/上下架按钮、商家页不传 `merchantId`、库存流水空条件拦截；新增静态自检脚本并修复其对 `.vue` default 导出的误报；补 R-01 菜单 `route_name` 补丁 SQL（未改 `03_seed.sql`，重跑 seed 后需再执行补丁） |
| 测试验证结果 | ①`cd admin-ui; node scripts/mall-check.mjs`：10 个页面 + 20 个 SFC 全部通过（`<script setup name>` 与路由名一致、component→文件全等、SFC 编译 0 error、`@/` import 全部可解析、权限码 ∈ 24 码、无 `console.*`/`addDateRange`/直接 axios）；②生产构建 `npm.cmd run build:prod` 成功（构建产物含各商城页面 chunk）；③接口契约静态对照：`@RequestMapping`/`@PreAuthorize`/`@RequestParam`/DTO 字段与设计文档 §3 逐条比对一致（A1–A24、M1–M11、`DashboardSummary` 5 字段、`ItemSaveRequest/SkuRequest/CategoryRequest/AuditRequest/ShipRequest/StatusRequest/StockAdjustRequest`）；④运行期联调未执行：本机无 Maven/JDK17、后端未构建启动，`shop` 库连接不可用，页面真实登录/取数待按 RUNBOOK 启动后端后回归（见 `verify/mall-frontend-20261026.txt` 的"未做项"） |
| 证据路径 | `admin-ui/src/{utils,api/mall,components/mall,views/mall}/**`、`admin-ui/scripts/mall-check.mjs`、`db/04_fix_menu_route_name.sql`、`verify/mall-frontend-20261026.txt` |

---

## AI-007 管理端前端静态自检、生产构建与接口契约对照验收

| 字段 | 内容 |
|---|---|
| 编号 | AI-007 |
| 日期 | 2026-10-26 |
| 阶段 | P4 前端验收（静态/构建，管理端） |
| 工具与模型 | DeepSeek Harness（deepseek-flash，Lead + 只读审查 Subagent） |
| Prompt 原文 | 延续 AI-006："完成前端项目的开发"→ 验收要求（隐含自设计文档 §9.4 DoD）：页面文件齐全不白屏、接口统一 `mallRequest`、权限码正确、`npm.cmd run build:prod` 成功、关键页面可联调；本机无 Vitest/Playwright/ESLint（§8.7 变更项），以"静态自检脚本 + 生产构建 + 后端源码契约对照"作为可执行验收证据 |
| 生成摘要 | ①新增 `admin-ui/scripts/mall-check.mjs`（243 行）：校验 10 个页面文件与 `<script setup name>`、菜单 component↔文件全等、20 个 SFC 的 `@vue/compiler-sfc` parse/compileScript/compileTemplate 0 error、`@/` import 可解析且导出名存在、`v-hasPermi` 权限码 ∈ 24 个 `mall:*`、无 `console.*`/`addDateRange`/直接 axios；②执行生产构建并留存日志摘要；③把 `@RequestMapping`/`@PreAuthorize`/`@RequestParam`/DTO 字段与设计文档 §3 逐条对照；④产出 `verify/mall-frontend-20261026.txt`（文件清单 33 个 / 7641 行、检查结果、构建结果、契约对照、未做项、已知偏差）、更新 `verify/README.md` 与根 `README.md`、补 `db/04_fix_menu_route_name.sql`（R-01） |
| 是否采纳 | 采纳（静态自检脚本纳入仓库，作为后续改动回归入口） |
| 修改理由 | 本机测试工具未安装（设计文档 §8.7 明确为非本次前置），生产构建 + SFC 编译 + 契约对照可覆盖"语法/依赖/白屏/参数口径"四类主要风险；运行期联调依赖后端环境，单独列为未做项。构建在本 DSH 沙箱下 `esbuild` 子进程直连系统 Temp 会被拒（`spawn EPERM`），验收时通过把 `TMP/TEMP` 指向工作区并放宽该步命令完成——**仅为沙箱环境事实，项目本身在普通 Windows 环境直接 `npm.cmd run build:prod` 即可** |
| 人工修改点 | 修复自检脚本首版对 `.vue` 文件"无 default 导出"的误报（`.vue` 的 `<script setup>` 由编译器生成 default 导出）；按文档回改库存页分页口径（§5.8.2）与低库存样式（§5.8.4）、审计页枚举改 `useDict`+`DictTag`（§5.9.4/§5.9.7）后重跑自检与构建；Lead 与只读审查对 33 个文件做 P0/P1 分级复核（跨组件 props/emits 契约、24 个权限码、日期/金额/快照/上传口径、Vue/Element Plus 用法），修复后重跑静态自检与生产构建 |
| 测试验证结果 | `node scripts/mall-check.mjs`：10 页面 / 20 SFC 全部通过（0 失败）；`npm.cmd run build:prod`：vite 6.4.1，2588 modules transformed，`✓ built in 34.63s`，EXIT=0，产物 `dist/` 355 文件 / 6.47 MB（基线同命令 2542 modules）；契约对照 A1–A24、M1–M11 路径/方法/权限码/参数名与 Controller 一致，`DashboardSummary` 5 字段与 `ItemSaveRequest/SkuRequest/CategoryRequest/AuditRequest/ShipRequest/StatusRequest/StockAdjustRequest` 字段与前端一致；未验证项：真实登录/动态菜单/接口取数（本机无 Maven/JDK17，后端未启动，MySQL/Redis 未就绪），R-01 补丁未执行（无可用 DB 连接） |
| 证据路径 | `verify/mall-frontend-20261026.txt`、`admin-ui/scripts/mall-check.mjs`、`admin-ui/dist/`（构建产物，Git 忽略）、`db/04_fix_menu_route_name.sql` |

---

## AI-008 生成《用户端（user-ui）前端详细设计 v1.0》

| 字段 | 内容 |
|---|---|
| 编号 | AI-008 |
| 日期 | 2026-10-26 |
| 阶段 | P2 设计（前端详细设计，用户端） |
| 工具与模型 | DeepSeek Harness（deepseek-flash，Agent Teams：Lead 1 + 写作队友 3：`writer-account`/`writer-catalog`/`writer-trade`，每域先产源码事实底稿再写契约与页面分片，Lead 统一提纲、基线、合稿与校核） |
| Prompt 原文 | "现在已经完成管理端的前后端开发，阅读需求文档和设计文档，完成用户端的具体设计文档"；上下文文件：`docs/01-需求文档/宠物商城系统_企业级需求文档_v2.0.md`（C-01～C-14、§4 流程/状态机、§8.2.1、§9 非功能、§10 验收、附录 A/C/D）、`docs/02-设计文档/宠物商城系统_企业级设计文档_v1.0.md`（§5/§6/§7/§8/§9）、`backend/ruoyi-mall/**`（已完成源码，契约唯一事实源）、`db/02_pet_mall.sql`、`db/03_seed.sql`、`docs/02-设计文档/管理端前端详细设计_v1.0.md`（同体例参照）、旧稿《用户端前端项目设计 v1.0》（仅骨架参考） |
| 生成摘要 | 生成 `docs/02-设计文档/用户端前端详细设计_v1.0.md`（7305 行 / 约 501 KB）：§0 文档信息、§1 概述与范围（18 页）、§2 总体设计（部署链路/分层/技术栈/目录 91 文件/环境变量/规范/联调基线）、§3 接口契约基线（Result/PageResult/会员鉴权/错误码 3 种失败形态/序列化/分页/幂等限流缓存 + **U01–U38 逐接口契约** + 差异 **D-01～D-38**）、§4 路由/布局/守卫/会话四态/双端边界、§5 十八个页面逐页设计（每页 9 子节 + 5 态 + 验收断言）、§6 请求层（三形态归一）/9 个 api/11 个 utils/24 个组件/4 个 store/校验总表/上传/骨架/设计 token/Mock 降级、§7 十四条关键流程、§8 非功能与测试、§9 WBS/里程碑/15 步联调/DoD/风险、附录 A 需求追溯（C-01～C-14 逐条）、B 状态枚举错误码、C 演示数据与 10 步脚本、D 文件清单与建卡、E 字段字典与坑位、F 自检清单。另产出 3 份源码事实底稿与 9 份分片（`docs/02-设计文档/_build_user/`，成稿后清理） |
| 是否采纳 | 采纳（18 页/38 接口/24 组件/14 流程全部定稿为实施基线） |
| 修改理由 | 后端已完成，旧稿的「Mock 先行」前提失效；实测发现 38 处与既有文档不一致（`LoginResponse` 无 `expiresIn`、`minPrice/maxPrice`、无 `onlyStock`/热词/业务缓存/下单限流、登录仅 10 次/60 秒限流、适配仅物种判 UNSUITABLE、地址删除保护键名错位、超时关单无调度、订单号 `PM…` 与 seed 不一致等），故以源码为契约基线并逐条登记差异与处置 |
| 人工修改点 | ①统一 §3.9 子编号为 3.9.1/3.9.2/3.9.3（三域分片原编号撞号）；②裁决「立即购买」口径：U30 只读购物车行 → 改为「U27 入车 + U28 校正数量 + U30 真实试算」，同步回改 §7.4/§7.5、U27/U30/U31 消费约定与 5.5/5.9 页面；③删除 §4.1 `/orders` 的 `keyword`（U32 无该参数）并在 5.12 标注后端缺口；④补第三失败形态（`AjaxResult{code:500,msg}` + HTTP 200）进 §3.4/§6.1；⑤补 `/profile` 开发代理、DOMPurify 富文本净化、`/profile` 图片占位兜底、消息 `targetUrl` 双格式映射；⑥清理分片中的工作流痕迹（T1/T3/Lead/facts 引用）与 4 处表格竖线转义破损；⑦附录 D 数量口径统一（源码 77 + 配置 9 + 静态 5 = 91） |
| 测试验证结果 | 无代码可执行（本任务为设计文档），已做静态校验：①标题结构 `## 0–9` + 附录 A–F 齐备；②5.1–5.19 每节 9 个 `####` 子节（19×9=171，脚本统计一致）；③U01–U38 连续无缺号、3.9.x 分组正确；④代码围栏 264 个成对；⑤表格列数脚本校验 0 破损（修复 4 处）；⑥全文检索无 TODO/待补充/工作流引用；⑦异常口径关键数字交叉对齐（18 页/38 接口/77 源码文件/91 新增文件/14 流程）；⑧契约字段与 Controller/DTO/Domain 逐条对照由三域事实底稿取证（`文件:行号`） |
| 证据路径 | `docs/02-设计文档/用户端前端详细设计_v1.0.md`；事实底稿与分片位于 `docs/02-设计文档/_build_user/`（合稿后已清理） |

---

## AI-009 整合协作者 `main` 分支（管理端前端落地）并统一为根目录平铺结构

| 字段 | 内容 |
|---|---|
| 编号 | AI-009 |
| 日期 | 2026-10-26 |
| 阶段 | P5 整合与回归（协作者分支合并） |
| 工具与模型 | Cline（VS Code Agent，Claude 系模型） |
| Prompt 原文 | "现在我的仓库协作者把他完成的部分上传到了仓库，请把我的和他的整合到一起" |
| 生成摘要 | fetch 到协作者分支 `github/main`（`4392d2a`，10 次提交、877 文件、根目录平铺）；与本地 `master`（`a5e86d5`，841 文件、`萌宠优选_后端交接包/` 包裹）为无共同祖先历史。以 `git merge --allow-unrelated-histories` 生成合并提交 `d439bb5`（双父 `a5e86d5` + `4392d2a`）；冲突仅 `.gitignore`/`README.md`（add/add），取平铺版；删除包裹目录（含 834 个 0 行变更的纯重命名）与根 `docs/` 两份重复副本；README 改为平铺结构与双远端说明；补 `.env.example`（入库）及本地 `.env.development`/`.env.production`；`index.html` 内联样式抽为 `public/loading.css`；`VITE_BUILD_COMPRESS` 改 `none`；新增 `verify/integration-20261026.txt`；随后协作者再推 `c71e738`（《用户端前端详细设计 v1.0》7305 行 + README/AI 日志同步），已二次合并入 `master`（AI 日志编号顺延，本条目定为 AI-009） |
| 是否采纳 | 采纳 |
| 修改理由 | ① 协作者分支已把交接包内容并入平铺结构，`git diff -M` 显示 834 个文件为 0 行变更的纯迁移，删除包裹目录不丢信息且结构更规范；② 根 `docs/` 两份副本经比对为 `pet_mall→shop` 更正前的旧版（新版在 `docs/01-需求文档`、`docs/02-设计文档`）；③ 协作者的 `.env` 被 `.gitignore` 排除，合并后构建缺 `VITE_APP_TITLE`，必须补环境文件；④ Vite 6.4.1 在 Windows 中文路径下处理 HTML inline-css 代理报错，外链 CSS 为最小修复；⑤ `vite-plugin-compression` 把 `.gz` 写到 `dist/d:/...` 异常路径，改由 Nginx 承担压缩 |
| 人工修改点 | 解决 `.gitignore`/`README.md` add/add 冲突（取平铺版后按双远端改写 Git 说明与目录名）；`git rm -r 萌宠优选_后端交接包`；删除根 `docs/` 两份重复副本；新增三个 `.env` 文件；用脚本精确抽取 `<style>` 到 `public/loading.css` 并替换为 `<link>`；`.env.production` 压缩改 `none`；登记 `verify/integration-20261026.txt` 与 `verify/README.md` |
| 测试验证结果 | 后端一致性：`git diff --stat backup/pre-integrate:萌宠优选_后端交接包/backend HEAD:backend` 无输出（逐字节一致）；前端增量：`admin-ui` 32 files / +8660 / -0；`npm install` 527 包 32s；`node scripts/mall-check.mjs` 10 页面 / 20 SFC 全部通过；`npm.cmd run build:prod` vite 6.4.1、2587 modules、`✓ built in 13.08s`、EXIT=0，`dist/` 含 `index.html`/`loading.css`/`static`（无异常 `.gz` 路径）；未执行：后端 `mvn package`（本机 `java`/`mvn` 不在 PATH）、运行期联调（需 JDK17 + MySQL + Redis）、`db/04_fix_menu_route_name.sql` |
| 证据路径 | `verify/integration-20261026.txt`、`verify/README.md`、`README.md`、`admin-ui/.env.example`、`admin-ui/public/loading.css` |

---

## AI-010 补录：实现商城后端 `ruoyi-mall` 模块（14 表领域模型 / 73 个接口 / 三端鉴权）

| 字段 | 内容 |
|---|---|
| 编号 | AI-010（补录条目） |
| 日期 | 2026-10-19（补录登记 2026-10-26；编号按日志追加顺序编排） |
| 阶段 | P3 后端开发（管理端 + 商家端 + 用户端接口） |
| 工具与模型 | AI 编码助手 + 人工审阅（协作者开发期间的原始工具/模型记录未随仓库提交，本条按合入源码、《后端开发交接说明 v1.0》与 2026-10-19 验收证据回溯整理） |
| Prompt 原文 | 任务目标（引自《后端开发交接说明 v1.0》§1 原文）："在已有 RuoYi 3.9.2 基座与 `shop` 数据库（14 张业务表、种子数据齐全）之上，**新增 `ruoyi-mall` 业务模块**，实现会员、宠物档案、商品、购物车、订单、支付沙箱、履约、RBAC 与测试，做到'登录 → 浏览 → 加购 → 下单 → 支付 → 发货 → 收货'主闭环可演示"；交付范围 M2–M10 见同文档 §3，工程/分层/鉴权约定见 §7、§8。原始对话未留存，以上为当时任务书条款。 |
| 生成摘要 | ①工程：`backend/ruoyi-mall` 共 **120 个 Java 文件 / 8480 行**（controller 22/1446、service 14/2658、domain 14/2122、dto 34/642、mapper 14/417、common 18/1021、config 1、state 2、event 1），`resources/mapper/mall/*.xml` 14 个；根 `pom.xml` 增加 `<module>ruoyi-mall</module>`，`ruoyi-admin/pom.xml` 增加依赖，`@MapperScan("com.ruoyi.**.mapper")` 与 `typeAliasesPackage` 直接覆盖新包，不改基座；②接口：**73 个 HTTP 映射**（GET 32 / POST 19 / PUT 18 / DELETE 4），按端与前端契约逐条对齐——管理端 `Admin*` 8 个控制器 23 个映射 + `POST /api/upload/image` = **A1–A24 共 24 项**；商家端 `Merchant{Item,Order,Stock}` 3 个控制器 **11 个映射 = M1–M11**；用户端 10 个控制器 37 个映射 + `POST /api/member/upload/image` = **U01–U38 共 38 项**（24+11+38=73）；③领域：14 个 domain 对应 `pet_*` 14 张表（收货/宠物/商品存快照，无物理外键），34 个 DTO 全为 `record` 且 27 处 `@Valid` 入参校验；④统一契约：`Result<T>`、`PageResult<T>`、`ErrorCode`（26 个 `PET-xxxx` 码，含 HTTP 状态与默认文案）、`BizException/AuthException/ForbiddenException/RateLimitException/DuplicateRequestException`、`MallExceptionHandler`（统一 `{code,msg,data,traceId}`）、`TraceIdFilter`（每请求生成 traceId 贯穿日志与响应）；⑤双域鉴权：后台沿用若依 JWT + `@PreAuthorize`（**34 处**，24 个 `mall:*` 权限码与 `db/03_seed.sql` 一致），会员侧 `@MemberLogin` + `MemberAuthInterceptor` + `MemberContext`(ThreadLocal) + `MemberTokenService`（Redis `member_tokens:` 前缀、UUID Token、剩余不足 1 天自动续期 7 天）+ `MallWebConfig` 注册拦截器与白名单，与后台 `login_tokens:` 完全隔离；⑥治理：`MallRateLimiter`（Redis 固定窗口，TTL 回填 `Retry-After`）、`MallConfigService`（读 `sys_config` 的 8 个 `mall.*` 键，全部带安全默认值）、**17 处 `@Log`** 写 `sys_oper_log` 审计、`MemberMessageEvent` 消息通知；⑦上传：`UploadController` 双入口（后台/会员）复用若依 `FileUploadUtils`，返回 `{url,fileName,newFileName,originalFilename}` 相对路径 |
| 是否采纳 | 采纳（已合入 `backend/`，已构建并完成运行验收） |
| 修改理由 | ①设计文档 §7.2 的 `service/impl/` 与 `job/` 分包未采用：Service 直接实现类、Controller 留在 `ruoyi-mall` 模块内（交接说明 §7.2 已注明实际位置），减少无意义抽象；②商城接口不复用若依 `AjaxResult`，独立 `Result` 以承载 `PET-xxxx` 业务码与 `traceId`，前端可区分"网络失败/业务失败/未登录"三形态；③会员 Token 不复用若依 JWT，避免后台与会员 Token 互用（冒烟第 21 项专测该隔离）；④金额全链路 `BigDecimal` + `DECIMAL(10,2)`，禁用 double/float；⑤限流不做"拦截器全局限流"，改为按场景显式调用（登录 10 次/60 秒、下单、回调），避免误伤浏览类只读接口；⑥上传按端拆两个路径而非共用一个，便于分别绑定后台 JWT 与会员 Token |
| 人工修改点 | 逐表核对 14 个 domain 与 `db/02_pet_mall.sql` 字段/类型/注释；核对 24 个权限码与 `sys_menu` 种子一致；确认 Controller 不写 SQL、`@Transactional(rollbackFor = Exception.class)` 只落在 Service 公有方法（35 处）；统一错误码与设计文档 §7.3 对照；补齐 DTO 的 `@Valid` 约束；接口按"只增不改"冻结为 v1 |
| 测试验证结果 | ①构建运行：`mvn -pl ruoyi-admin -am -DskipTests package` 成功，产物 `dist/ruoyi-admin.jar` 可启动（交接说明 §0/§4 记录）；②数据库侧：`db/verify.sql` A/B/C 共 35 项 PASS；③接口侧：`setup/smoke-test.ps1`（只读）**PASS=30 FAIL=0 SKIP=0**——公开接口 4、会员域 8（含未登录 HTTP 401 + `biz=2001`）、管理员域 8、后台/会员 Token 隔离 1（会员 Token 调后台接口 → `biz=401`）、商家域 4（含越权 `biz=403`）、审核员域 5（含越权 `biz=403`），证据 `verify/evidence-20261019.txt`；④**未做（如实登记）**：`ruoyi-mall/src/test` 不存在、无 JaCoCo，交接说明 M10 要求的"核心 Service 单测 + 并发/幂等/超时测试"未交付，测试报告缺位 |
| 证据路径 | `backend/ruoyi-mall/**`、`backend/pom.xml`、`backend/ruoyi-admin/pom.xml`、`verify/evidence-20261019.txt`、`verify/backend-20261019.txt`、`setup/smoke-test.ps1`、`docs/02-设计文档/后端开发交接说明_v1.0.md` |

---

## AI-011 补录：交易链路一致性机制（原子扣减 / 支付幂等 / 状态机 / 超时关单）

| 字段 | 内容 |
|---|---|
| 编号 | AI-011（补录条目） |
| 日期 | 2026-10-19（补录登记 2026-10-26；编号按日志追加顺序编排） |
| 阶段 | P3 后端开发（核心交易链路） |
| 工具与模型 | AI 编码助手 + 人工审阅（同 AI-010，按源码回溯补录） |
| Prompt 原文 | 引自交接说明 §6.3/§9 的开发约定原文："扣减 SQL `UPDATE pet_item_sku SET stock=stock-#{qty} WHERE id=#{skuId} AND stock>=#{qty}`，影响 0 行 → `PET-3001` 并整单回滚"；"支付回调 `Idempotency-Key` 必须落 `pet_payment.idempotency_key`，重复命中唯一键直接返回成功且不改订单"；"超时关单…条件更新 `WHERE status=0`，再回滚库存"；"先按 `sku_id` 升序扣减，降低死锁概率；状态更新一律条件更新" |
| 生成摘要 | ①`StockService`：`deduct/rollback/adjust` 三入口 + `writeLog`；扣减前查 `pet_stock_log.uk_sku_order_type` 流水判重（重跑不重复扣），`deductStock` 影响 0 行即抛 `PET-3001` 由事务整单回滚；`PetItemSkuMapper.deductStock` 为 `WHERE id=? AND status=1 AND stock >= #{quantity}` 原子条件更新（禁止先查后改），并叠加 DDL `CHECK(stock>=0)` 兜底；②`PriceCalculator`：`Σ(price×qty)` → 免邮阈值（`mall.freight-free-threshold`）→ 运费（`mall.freight-fee`）→ 应付，全程 `BigDecimal` + `HALF_UP` 两位小数，一期 `discountAmount` 恒 0；③`CheckoutService`：试算与下单共用计价，下单校验同店（不同 `merchant_id` → `PET-1001`）、按 `skuId` 升序扣减、写订单与明细快照、清购物车、`incrementSales`；订单号 `PM + yyyyMMddHHmmss + 6 位随机`；④`OrderStateMachine`：9 状态（0 待付款…8 已退款）迁移矩阵 + `assertTransition`（非法迁移 → `PET-3002`）+ `assertCurrent`；⑤`PaymentService`：沙箱三分支（`mockPay`）与回调（`callback`）共用 `settle`；回调用 `mall.pay-callback-token` 校验令牌后比对金额（不一致 → `PET-4002`），幂等键**先查后插**、命中即返回 `duplicated=true` 且不改订单，成功用 `updateToPaid` 条件更新（并发时回读最新状态，避免状态回退）；⑥`OrderService`：取消回滚库存并写 `ORDER_ROLLBACK` 流水、商家/平台发货（状态断言 + 物流信息追加进 `receiverSnapshot`）、确认收货、`closeTimeoutOrders`（单批 100 单，逐条条件关单后回滚库存并发消息）、`autoConfirmOrders`（按 `mall.auto-confirm-days`）；⑦`AdminJobController`：A22/A23 手动补偿入口（`mall:job:trigger`）；⑧`PetItemMapper.updateAudit`：审核驳回时 `status` 强制置 0 |
| 是否采纳 | 采纳（核心链路按设计落地）；3 项降级/未采纳见"修改理由" |
| 修改理由 | ①**超时关单与自动确认未接 Quartz**：`ruoyi-mall` 下无 Job 类、`sys_job` 无商城记录，仅保留 A22/A23 手动接口 → 演示与文档不得声称"定时自动"（管理端前端设计 §9.5、用户端设计 D-31 均已登记）；②`updateAudit` 未带 `AND audit_status=0`：两个管理员并发审核可能相互覆盖 → 前端只对 `auditStatus=0` 显示审核按钮并在成功后强制刷新，后端补条件更新列为待修复项；③扣减条件含 `status=1`：SKU 下架后扣减同样返回 `PET-3001`（语义上属"不可售"），前端按库存不足提示，为已知口径；④一期无优惠券/折扣，`discountAmount` 固定 0，促销与价保留二期 |
| 人工修改点 | 复核扣减 SQL 原子条件与流水唯一键（`uk_sku_order_type`）双保险；批量扫描上限固定 100；关单与取消复用同一 `rollbackStock`，保证流水 `Σchange_qty = stock`；状态推进一律条件更新 + 回读校验；金额比较用 `compareTo` 而非 `equals`；`@Transactional(rollbackFor = Exception.class)` 覆盖取消/关单/支付全链 |
| 测试验证结果 | ①冒烟覆盖：会员侧购物车与订单列表、管理员侧订单与库存查询、商家侧商品与订单、支付记录查询均 HTTP 200 + `biz=200`；②证据：`verify/evidence-20261019.txt` **PASS=30/FAIL=0**；③**未做（如实登记）**：`StockConcurrentTest`（20 线程抢库存 1）、回调重放 3 次、状态机全矩阵单测、超时关单实跑（需时间回拨或 `mall.pay-timeout-minutes=1`）均未落地——`backend/ruoyi-mall/src/test` 为空，上述验收口径目前只有代码级保证与静态对照，无自动化执行记录；已列入下一步"测试三件套（防超卖/支付幂等/状态机）+ JaCoCo"任务 |
| 证据路径 | `backend/ruoyi-mall/src/main/java/com/ruoyi/mall/service/{StockService,CheckoutService,OrderService,PaymentService,PriceCalculator}.java`、`.../state/OrderStateMachine.java`、`.../resources/mapper/mall/{PetItemSkuMapper,PetItemMapper}.xml`、`.../controller/AdminJobController.java`、`verify/evidence-20261019.txt`、`verify/backend-20261019.txt` |

---

## AI-012 仓库文件隔离测试与异机启动问题排查

| 字段 | 内容 |
|---|---|
| 编号 | AI-012 |
| 日期 | 2026-10-27 |
| 阶段 | 测试验收与运行排错 |
| 工具与模型 | Codex（GPT-6），PowerShell、Git、Node.js/npm、Maven |
| Prompt 原文 | “现在出现了问题：在非本机的运行环境下客户端无法打开，你来根据仓库文件进行测试。注意：只用仓库文件进行测试，不要上传新文件”；后续核对：“我的环境和仓库的环境一致吗” |
| 生成摘要 | 以 `master@406cdf5` 为基线，通过 `git archive` 导出干净源码快照，并解压仓库已提交的 `docs/05-交付包/pet-mall-v2.3.0.zip` 对照测试；不复制本机真实配置、既有 `node_modules` 或构建产物。依赖按快照内锁文件安装。检查启动脚本、接口代理、生产构建及本机与仓库的环境差异，没有修改业务源码或上传文件 |
| 是否采纳 | 采纳（完成隔离测试与问题定位；本条不包含问题源码修复） |
| 修改理由 | 本机存在被 Git 忽略的配置、依赖和构建结果，直接在原工作目录测试会掩盖干净检出时的前置条件。先排除测试沙箱阻止回环连接与下载依赖的影响，再执行本地 HTTP 验证，避免把测试环境限制误判为项目缺陷 |
| 人工修改点 | 未记录新增人工代码修改；按用户约束只使用仓库源码、锁文件及仓库内交付包作为项目测试输入，生成物仅保留本机 |
| 测试验证结果 | ①用户端 `npm test`：5 项通过；`npm run check`：19 个页面、59 个 Vue 文件通过；用户端与管理端生产构建成功，管理端静态自检覆盖 10 个页面、20 个 SFC；后端 `mvn -o -DskipTests package` 成功，属于编译打包验证，未执行 Java 单测。②交付 ZIP 的 SHA-256 与仓库校验文件一致，包内 manifest 的 1273 项文件校验全部通过。③交付用户端首页、入口 JS/CSS 和深层路由返回 HTTP 200，缺失静态资源返回 404；刻意指定不存在的后端时，代理按预期返回 JSON 503。④服务实际只监听 `127.0.0.1`，通过本机局域网 IP 连接测试端口超时；开发与预览命令也限制在回环地址。⑤管理端缺少 `.env.production` 时仍可构建，但产物中接口 `baseURL` 为 `undefined`，登录请求返回 405；交付包产物使用 `/prod-api`，代理路由正常。生产配置必须按 RUNBOOK 生成，不能把模板默认的 `/dev-api` 直接用于生产运行服务。⑥本轮为本机隔离测试，未在真实异机环境执行，也未在隔离快照中部署数据库完成业务验收 |
| 证据路径 | 仓库：`setup/serve-user-ui.mjs`、`setup/start-mall.ps1`、`user-ui/package.json`、`admin-ui/.env.example`、`admin-ui/src/utils/request.js`、`RUNBOOK.md`、`docs/05-交付包/pet-mall-v2.3.0.zip.sha256`；本机隔离目录：`D:/AI大作业/repo-only-test-20261027-205239/`（不入库）及本轮命令输出 |

---

## AI-013 按仓库文档对齐本机环境并完成启动回归

| 字段 | 内容 |
|---|---|
| 编号 | AI-013 |
| 日期 | 2026-10-27 |
| 阶段 | 环境配置、构建与回归验收 |
| 工具与模型 | Codex（GPT-6），PowerShell、Windows 任务计划程序、Node.js/npm、Maven、MySQL、Redis |
| Prompt 原文 | “能不能改成完全符合仓库的环境”；日志追加要求：“补充一下开发日志” |
| 生成摘要 | 先备份本机配置、原后端 JAR 和 `PetMall-Redis` 启动任务，再从仓库模板生成本地配置并保留必要凭据。后端非敏感有效配置与 `config/backend.env.example` 对齐，其中 `DB_ALLOW_PUBLIC_KEY_RETRIEVAL` 调整为模板值 `true`；管理端生成开发配置，并按 RUNBOOK 设置生产环境与 `/prod-api`。前后台分别执行 `npm ci`，重装锁定依赖并重建；后端执行 `mvn -DskipTests clean package`。发现原 Redis 为 8.10.2，与文档要求的 Redis 7 不一致，单独安装 Redis 7.4.11 并切换本项目任务；保留 Redis 8 程序及其数据。通过仓库 `setup/start-mall.ps1 -NoBrowser` 启动商城，并后台启动管理端生产服务 |
| 是否采纳 | 采纳（本机项目运行环境已按仓库文档要求对齐） |
| 修改理由 | “环境对齐”采用仓库声明的版本要求、锁文件、配置模板和部署步骤，不代表删除运行必需的本地配置，也不要求重置为种子数据。Node 24.21.0、npm 11.19.0、JDK 17.0.20.1、Maven 3.9.9、MySQL 8.0.43 保持使用；Redis 实际运行版本改为 7.4.11。Redis 7 使用独立数据目录，未转换或覆盖 Redis 8 的持久化文件，旧登录态不会自动迁入新实例 |
| 人工修改点 | 未记录新增人工代码修改；本轮仅调整本机配置、生成依赖与构建产物、项目 Redis 启动任务。未修改受版本控制的应用源码、未清库、未执行种子数据重置、未提交或推送；本条日志本身为后续追加的文档变更 |
| 测试验证结果 | ①前后台分别安装 139/527 个依赖包；直接依赖 11/25 项与各自锁文件版本完全一致。用户端 5 项单测、19 页/59 个 Vue 文件检查，管理端 10 页/20 个 SFC 检查及两端生产构建全部通过；后端 clean/package 成功，Java 测试按 `-DskipTests` 跳过。②Redis 发布包 SHA-256 为 `ec629971d76756dd040204297f1a92f43848e7a5f4862d39426beeafcca2a2a9`，与发布资产摘要匹配；项目任务启动后 PING 返回 PONG，INFO 确认实际版本为 7.4.11。③商城入口启动成功，用户端首页、深层路由、商品列表接口返回 HTTP 200；`/api/health` 返回数据库与 Redis 均 UP。④通过管理端 `/prod-api` 代理执行仓库 `setup/smoke-test.ps1`，结果 `PASS=30 FAIL=0 SKIP=0 TOTAL=30`，覆盖公开接口、会员/管理员/商家/审核员登录及权限隔离。⑤现有 `shop` 数据库保持 48 张表，执行 `db/verify_runtime.sql` 的 10 项只读一致性校验全部 PASS；未重置业务数据。⑥环境操作完成时 `git status --porcelain` 为空，非敏感后端配置与模板差异为 0。服务仍沿用仓库的回环监听方式，本轮未修复跨设备访问限制，也未声称完成真实异机验收 |
| 证据路径 | 仓库：`config/backend.env.example`、`admin-ui/.env.example`、`RUNBOOK.md`、`setup/start-mall.ps1`、`setup/smoke-test.ps1`、`db/verify_runtime.sql`；本机：`logs/console.log`、`logs/user-ui.log`、`logs/admin-ui.log`、`D:/AI大作业/local-env-backup-20261027-210638/smoke-result.txt`（30 项结果）、同目录的原配置/JAR 与 `PetMall-Redis.original.xml`；Redis 7 安装目录：`D:/dev/petmall-redis-7.4.11/Redis-7.4.11-Windows-x64-msys2/`。本机备份、日志、凭据和运行环境均不随日志入库；发布来源：[Redis Windows 7.4.11](https://github.com/redis-windows/redis-windows/releases/tag/7.4.11) |

---

## AI-014 本地模拟换机全流程测试与脱敏证据归档

| 字段 | 内容 |
|---|---|
| 编号 | AI-014 |
| 日期 | 2026-10-27 |
| 阶段 | 部署验收与交付归档 |
| 工具与模型 | Codex（GPT-6），Git、PowerShell、Node.js/npm、Maven、独立 MySQL/Redis 实例、浏览器 |
| Prompt 原文 | “测试一下非本机本地测试”；测试后归档授权：“现在把这些东西和日志一起上传” |
| 生成摘要 | 重新从 `master@406cdf5` 导出干净源码及仓库内交付 ZIP，使用空 npm/Maven 缓存、模板生成的配置与测试凭据、全新数据库/Redis 数据目录和独立端口，验证从建库到构建、启动、接口代理和浏览器登录的流程。源码与运行包均启动成功。按后续明确授权，将本次及此前开发日志与脱敏结果归档到仓库，原始凭据、会话响应、数据库与缓存仅留本机 |
| 是否采纳 | 采纳（完成本地隔离验收及日志、脱敏证据归档） |
| 修改理由 | AI-012 仅做了源码/交付包构建及离线代理检查，未给隔离副本部署数据库；本轮补上独立 MySQL/Redis、首次建库和真实接口验收。测试运行在同一台 Windows 电脑，运行时程序仍来自本机安装，不将进程/配置/数据隔离夸大为真实异机或虚拟机验收 |
| 人工修改点 | 未记录新增人工业务源码修改；归档范围为本日志、`verify/README.md` 和 `verify/fresh-machine-20261027/`。冒烟原始响应含临时 Token，归档只保留逐项判定和汇总；截图原字节为 JPEG，按实际格式以 `.jpg` 保存，未修改图像内容 |
| 测试验证结果 | ①全新 `shop` 库由仓库 `init-db.ps1` 初始化为 48 张表，测试使用独立的 13306/16379 数据库与缓存端口，不接触原项目数据。②用户端 5 项单测、19 页/59 个 Vue 文件检查，管理端 10 页/20 个 SFC 检查及两端构建通过；后端从空 Maven 缓存和空用户/全局设置构建成功，Java 单测按 `-DskipTests` 跳过。③源码/运行包经各自管理端代理分别通过 30 项冒烟检查，均 `FAIL=0 SKIP=0`；另有 22 项 HTTP 检查和 10 项数据库只读校验通过。④浏览器显示运行包首页商品、源码用户端会员登录成功及源码管理端登录页。⑤按 Git 换行规则核对 1049 个快照文件，内容差异为 0；运行包未安装前端 `node_modules`。⑥未执行文件上传；测试结束已关闭隔离服务，原项目健康检查正常。⑦保留边界：仍只监听回环地址，没有验证真实异机、跨设备访问或真实支付 |
| 证据路径 | [验收说明](../../verify/fresh-machine-20261027/README.md)、`verify/fresh-machine-20261027/test-receipt.json`、`source-smoke.txt`、`release-smoke.txt`、`http-results.json`、`runtime-db.txt`、`source-login.jpg`；完整临时副本、原始日志、数据目录与凭据不上传 |

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
