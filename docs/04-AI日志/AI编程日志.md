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
