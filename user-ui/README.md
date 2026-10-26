# 萌宠优选 · 用户端

独立 Vue 3 用户商城，直接消费现有 `ruoyi-mall` 接口。会员 Token 使用 `localStorage.member_token`，与管理端隔离。

## 启动

要求 Node 18+，推荐使用当前已安装的 Node 22。先按仓库根运行手册启动 MySQL、Redis 与后端。

```powershell
cd user-ui
npm.cmd ci
npm.cmd run dev
```

也可以双击仓库根 `start-user-ui.bat`。打开 `http://127.0.0.1:81/`。

默认代理 `/api`、`/profile` 到 `http://127.0.0.1:8080`。如果后端端口不同，复制 `.env.example` 为 `.env.local` 并调整 `VITE_API_TARGET`，重启 Vite。`VITE_*` 变量会进入前端环境，不能填写密码或密钥。

演示账号：`member1 / member123`、`member2 / member123`。这些是会员账号，后台管理员账号不能在用户端登录。

## 实现范围

- 18 条路由：首页、商品列表、搜索、商品详情、登录、注册、购物车、结算、沙箱支付、支付结果、订单列表、订单详情、个人中心、宠物档案、收货地址、消息中心、协议/隐私/关于、404。
- 商品分类树、物种/年龄/价格筛选、排序与分页；查询状态保存在 URL。
- SKU、库存限制、每宠适配结论；商品描述经 DOMPurify 白名单清理后渲染，禁止原始 `v-html`。
- 注册与登录校验、登录回跳、过期/禁用清态、429 等待、错误码和 traceId 提示。
- 游客可在详情加购，登录后逐行合并；已成功合并的行立即从本地移除，失败行保留并可重试。购物车页按设计要求会员登录。
- 头像上传、资料修改、宠物新增/编辑/归档、地址新增/编辑/删除/默认、消息已读与安全跳转。
- 服务端金额试算、同店铺校验、下单幂等、取消、发货物流展示、确认收货。
- 下单请求先保存在当前会员的 `sessionStorage`，网络结果不确定时重发原请求及原 `clientToken`。支付结果重新向后端查询，URL 中的结果参数不能伪造成功。
- 已取消页签合并状态 5/6 并正确分页；支付倒计时只用于提示，不自行改变后端订单状态。
- 桌面与手机布局、懒加载路由、按需引入 Element Plus、加载/空/错误/提交状态、缺图兜底。

## 校验

```powershell
npm.cmd test       # 错误解包、跳转安全、快照、跨状态分页
npm.cmd run check  # 18 页面、全部 SFC 编译、导入及会员域边界
npm.cmd run build # 生产构建
```

真实接口验收（先启动后端和 Vite）：

```powershell
node scripts/integration.mjs
```

脚本只创建专用测试会员及虚拟数据，不清空已有数据库。它会提交并取消一笔订单、创建一笔已支付的沙箱订单，因此会留下测试记录并扣减一件测试商品库存。验收结果写入 `../verify/user-ui/api-receipt.json`。重复执行会创建新的测试账号和记录，勿用于生产环境。

浏览器验收记录及截图见 `../verify/user-ui/`。

## 部署

`npm.cmd run build` 生成 `dist/`。`npm.cmd run preview` 仅用于本机预览，默认端口 4181。生产环境需要反向代理后端与上传资源，并为 History 路由配置回退，例如：

```nginx
location / { try_files $uri $uri/ /index.html; }
location /api/ { proxy_pass http://127.0.0.1:8080; }
location /profile/ { proxy_pass http://127.0.0.1:8080; }
```

## 实现边界

- 支付仅为教学沙箱，不连接真实支付渠道。
- 原种子图片没有实体文件，显示“商品图片暂缺”的插画兜底；业务图片到位后自动展示。
- 修改密码、换绑、注销、优惠券、订阅、售后及物流轨迹接口尚未实现，页面不调用这些接口。
- 后端没有定时关单调度，前端在时间到达时提示刷新；需要由现有后台任务处理。
- 后端修改购物车不能通过 `petId=null` 清除宠物关联，因此已有宠物的购物车行只提供替换关联。
- 本机首次启动新构建的后端时，MySQL 的认证要求本地 JDBC 参数 `allowPublicKeyRetrieval=true`。本次通过进程环境变量覆盖连接 URL，未改后端源码。该临时参数仅用于本机联调；正式环境应使用受信任的 TLS 配置。

本机后端重启可在仓库根目录运行（脚本按需提示输入已有数据库密码）：

```powershell
$env:SPRING_DATASOURCE_DRUID_MASTER_URL='jdbc:mysql://127.0.0.1:3306/shop?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=GMT%2B8'
powershell -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -NoWait
```

源码位于 `src/`；接口分为 9 个模块，状态分为 member/cart/pet/app 四个 Pinia store。所有页面经统一请求层访问接口；未引入 Mock 成功数据。
