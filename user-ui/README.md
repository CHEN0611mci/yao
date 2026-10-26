# 萌宠优选 · 用户端 v1.1.0

Vue 3 商城，使用真实 ruoyi-mall API。会员 Token 与管理端隔离，不使用 Mock 成功数据。

## 本机启动

双击仓库根目录 **start-mall.bat**（start-user-ui.bat 同入口），打开 http://127.0.0.1:81/ 。脚本启动已安装的 MySQL / Redis，等待后端 `/api/health` 同时确认数据库与 Redis 可用，再启动生产前端及接口代理。端口可用本身不算服务就绪。

本机配置在 Git 忽略的 config/backend.env；换机从 backend.env.example 复制并填写。首次初始化按 RUNBOOK.md 操作；日常启动不会清空数据库。需要 Node 18+、JDK 17+、MySQL 8 和 Redis；源码重建后端需要 Maven 3.9+。运行包已有 JAR 和前端构建，无须安装前端依赖。

开发时在本目录运行 `npm.cmd ci`、`npm.cmd run dev`，须先启动后端。默认代理 http://127.0.0.1:8080，可用 .env.local 的 VITE_API_TARGET 调整。VITE_* 中不要填写密钥。演示会员：member1 / member123、member2 / member123。

## 功能

- 18 条路由，桌面与手机布局，统一加载、错误、空态和缺图提示。
- 可配置首页轮播、服务说明、热词、搜索历史；分类树、价格、年龄、物种、库存、指定宠物筛选及排序分页。
- 商品 SKU、按宠适配、风险确认、富文本净化；成本价不返回用户端。
- 注册登录、头像资料、修改密码（验证原密码，变更后全部会员会话失效）、安全退出。
- 宠物档案新增/编辑/归档/恢复/JSON 导出；地址管理、消息、客服说明及反馈落库。
- 游客购物车逐行合并、数量/选择/宠物关联、清除关联、按宠查看、批量移除所选、清理失效商品。
- 服务端试算、同店结算、库存条件扣减、幂等下单、取消回滚、沙箱支付三分支、支付结果回查。
- 订单搜索、发货前改地址、按当前价格再次购买、物流单号、确认收货；定时超时关单及自动确认收货。

## 校验

```powershell
npm.cmd test
npm.cmd run check
npm.cmd run build
node scripts/integration.mjs
node scripts/repair-integration.mjs
node scripts/stock-concurrency.mjs
```

后三个脚本须在本机教学环境运行，会创建专用虚拟账号、地址和订单。repair-integration 读取本机数据库配置，仅修改本次新建测试订单时间验证调度，不重置数据。并发脚本创建专属 SKU，结束后下架。普通回归会留下沙箱支付记录并扣减少量商品库存。证据在 verify/user-ui/ 和 verify/repair/。

## 运营配置

管理员在系统管理 → 参数设置维护以下键，修改后刷新缓存及前台。缺省时使用内置演示内容。

- mall.home.banners：JSON 数组，字段 title/subtitle/image/path/sort/enabled/startsAt/endsAt，时间格式 2026-10-27T00:00:00。仅站内路径。示例：`[{"title":"认真挑选","subtitle":"照顾它的日常","image":"/images/companions.svg","path":"/items","sort":0,"enabled":true}]`。若依参数值长度上限 500 字。
- mall.home.promises：逗号分隔服务说明。
- mall.search.hot-keywords：逗号分隔热词。
- mall.support.description：客服说明；反馈在监控 → 操作日志查看，标题“商城意见反馈”。
- mall.catalog.blocked-words：逗号分隔禁售词。
- mall.order-max-amount：单笔金额上限，默认 100000。
- mall.pay-timeout-minutes / mall.auto-confirm-days：超时参数。自动关单每 30 秒、确认收货每 60 秒扫描。可通过 Spring 属性 mall.jobs.enabled=false 关闭自动调度。

## 交付范围

本轮按一期商城主流程修复并补齐接口缺口。真实支付、处方药资质、优惠券、订阅扣款、售后工单、发票、多商户、社区属于二期，仍未实现；换绑、注销、设备列表、通知偏好也没有实现接口。以上不算已交付能力。

种子商品没有真实图片文件，页面明确显示缺图插画；不代表 API 没有数据。生产部署仍需真实素材和生产配置。

setup/serve-user-ui.mjs 使用 Node 内置模块，提供 History 回退、/api 和 /profile 代理。后端故障返回 JSON 503，不伪装成空列表。正式部署可改用 Nginx。支付仅为教学沙箱。
