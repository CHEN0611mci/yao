# -*- coding: utf-8 -*-
"""Generate design-document diagrams (architecture, deployment, sequence, ER).

Reuses the drawing helpers of gen_figures.py (SRS V1/V2 figures) so that the
design document stays visually consistent with the requirements document.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gen_figures import (  # noqa: E402
    Image, ImageDraw, new_canvas, draw_round, text, arrow, poly_arrow, font,
    save, S, NAVY, BLUE_L, BORDER, ACCENT, ACCENT_B, GREEN, GREEN_B, GRAY, GRAY_B,
    RED, RED_B, WHITE, INK, fit_font, label_box, wrap_text,
)

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(BASE, "docs", "02-设计文档", "images")
os.makedirs(OUT, exist_ok=True)


def save(img, name):  # noqa: F811 - 覆盖 gen_figures.save，改写到设计文档目录
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    print("saved", path, img.size)


def titled(img, title, w, sub=None):
    d = ImageDraw.Draw(img)
    text(d, (w / 2, 42), title, font(21, True), fill=NAVY)
    if sub:
        text(d, (w / 2, 74), sub, font(14), fill=(110, 110, 110))


def card(d, cx, cy, w, h, main, sub="", fill=BLUE_L, outline=BORDER,
         main_size=17, sub_size=13, dashed=False):
    draw_round(d, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 9, fill, outline, 2)
    if dashed:
        arrow(d, (cx - w / 2 + 4, cy - h / 2), (cx + w / 2 - 4, cy - h / 2),
              color=outline, width=1, dashed=True, head=False)
    if sub:
        text(d, (cx, cy - h / 2 + 26), main, fit_font(main, w - 24, main_size, 12))
        sub_lines = sub.split("\n")
        for i, ln in enumerate(sub_lines):
            text(d, (cx, cy - h / 2 + 56 + i * 23), ln,
                 fit_font(ln, w - 24, sub_size, 10), fill=(95, 95, 95))
    else:
        text(d, (cx, cy), main, fit_font(main, w - 24, main_size, 12))


def zone(d, x1, y1, x2, y2, label, fill=(248, 250, 252), outline=(205, 216, 228),
         label_color=NAVY, label_size=16):
    draw_round(d, (x1, y1, x2, y2), 12, fill, outline, 2)
    if label:
        text(d, (x1 + 18, y1 + 22), label, font(label_size, True), fill=label_color,
             anchor="lm")


# ---------------------------------------------------------------- fig 3-1 arch
def fig_arch():
    W, H = 1800, 1320
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    LX1, LX2 = 60, 1265
    bands = [
        ("接入层\nC / A 域页面", 86, 196),
        ("代理与入口", 214, 312),
        ("Web 层\nruoyi-admin", 330, 512),
        ("业务层\nruoyi-mall", 530, 842),
        ("基础能力层", 860, 1004),
        ("数据与存储", 1022, 1216),
    ]
    for label, y1, y2 in bands:
        zone(d, LX1, y1, LX2, y2, "")
        text(d, (LX1 + 26, (y1 + y2) / 2), label, font(16, True), fill=NAVY)

    # band 1
    card(d, 430, 141, 258, 82, "客户前台 SPA · user-ui", ":81 · Vue3 + Vite6 + Element Plus")
    card(d, 740, 141, 258, 82, "管理后台 SPA · admin-ui", ":80 · RuoYi-Vue3（复用）")
    card(d, 1050, 141, 258, 82, "H5 / 小程序（目标态）", "复用同一套 /api 契约", GRAY, GRAY_B)
    # band 2
    card(d, 470, 263, 300, 74, "Vite Dev Proxy  /api → :8080", "开发期同源代理，规避 CORS")
    card(d, 790, 263, 300, 74, "（可选）Nginx 反向代理", "生产态静态资源 + 转发", GRAY, GRAY_B)
    card(d, 1110, 263, 300, 74, "CORS / HTTPS（生产预留）", "一期本机 HTTP 演示", GRAY, GRAY_B)
    # band 3
    web = [
        ("过滤器链 Filter", "TraceId · XSS · Repeatable"),
        ("鉴权与限流", "Spring Security(JWT)\n@MemberLogin · 令牌桶"),
        ("Controller 层", "前台 / 商家 / 后台 / 回调\n@Valid 参数校验"),
        ("全局异常 / 统一返回", "@RestControllerAdvice\nResult{code,message,data,traceId}"),
    ]
    for i, (m, s) in enumerate(web):
        card(d, 400 + i * 256, 421, 236, 150, m, s, ACCENT, ACCENT_B, 16)
    # band 4
    mods = [
        ("会员与档案", "认证 · 档案 · 地址"), ("商品与 SKU", "分类 · 商品 · 审核"),
        ("购物车与结算", "加购 · 试算 · 运费"), ("订单与状态机", "下单 · 六页签 · 流转"),
        ("支付与幂等", "沙箱 · 回调 · 幂等键"), ("库存与流水", "原子扣减 · 回滚 · 对账"),
        ("消息与通知", "站内信 · 模板 · 未读"), ("后台治理", "审核 · 发货 · 会员 · 审计"),
    ]
    for i, (m, s) in enumerate(mods):
        cx = 330 + (i % 4) * 256
        cy = 620 + (i // 4) * 156
        card(d, cx, cy, 240, 140, m, s, GREEN, GREEN_B, 17)
    # band 5
    base = [
        ("ruoyi-framework", "安全 · 数据源 · 事务"),
        ("ruoyi-system", "RBAC · 字典 · 参数"),
        ("ruoyi-quartz", "超时关单 · 自动收货"),
        ("ruoyi-common", "Result · 异常 · 工具"),
        ("Springdoc / Actuator", "OpenAPI · health · 指标"),
    ]
    for i, (m, s) in enumerate(base):
        card(d, 358 + i * 210, 932, 194, 122, m, s, BLUE_L, BORDER, 15, 12)
    # band 6
    store = [
        ("MySQL 8.0", "pet_mall：pet_* 14 表\n+ sys_* / qrtz_*", BLUE_L, BORDER),
        ("Redis 7", "DB0 Token · DB1 缓存\n限流计数", BLUE_L, BORDER),
        ("文件存储", "uploadPath\n商品图 / 凭证", BLUE_L, BORDER),
        ("目标态扩展", "MQ · 对象存储\n云搜索 · 链路追踪", GRAY, GRAY_B),
    ]
    for i, (m, s, f, o) in enumerate(store):
        card(d, 390 + i * 256, 1119, 236, 150, m, s, f, o, 17)

    # vertical connectors between bands
    for y1, y2 in [(196, 214), (312, 330), (512, 530), (842, 860), (1004, 1022)]:
        arrow(d, (663, y1 + 2), (663, y2 - 2), width=2, color=(120, 130, 145))

    # cross-cutting column
    CX1, CX2 = 1300, 1740
    zone(d, CX1, 330, CX2, 1216, "")
    text(d, ((CX1 + CX2) / 2, 358), "横切关注点", font(17, True), fill=NAVY)
    cross = [
        ("安全与鉴权", "认证 · RBAC · 归属校验\n注入/XSS · 限流 · 脱敏"),
        ("日志与 traceId", "MDC 贯穿全链路\n结构化日志 · 180 天留存"),
        ("监控与健康", "/actuator/health\nPrometheus 指标"),
        ("配置与参数", "@ConfigurationProperties\n系统参数表 · 变更留痕"),
        ("审计与合规", "sys_oper_log 只增不改\n禁售词库 · 隐私文案"),
        ("测试与证据", "JUnit / 并发 / k6\nseed 与可复现脚本"),
    ]
    for i, (m, s) in enumerate(cross):
        card(d, (CX1 + CX2) / 2, 432 + i * 132, CX2 - CX1 - 40, 116, m, s, (245, 248, 252),
             (176, 194, 214), 16, 12)

    titled(img, "图 3-1 系统逻辑架构（分层 + 模块 + 横切关注点）", W,
           "自下而上单向依赖；横切能力不进入业务代码，由框架与统一入口实现")
    save(img, "fig-3-1-arch.png")


# ------------------------------------------------------------- fig 3-2 modules
def fig_modules():
    W, H = 1740, 1140
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    zone(d, 60, 96, 560, 470, "会员域（C-05 / C-10 / C-14）")
    member_mods = [("会员认证", "注册 · 登录 · Token"), ("宠物档案", "建档 · 适配数据源"),
                   ("收货地址", "CRUD · 默认唯一"), ("个人中心", "资料 · 消息 · 协议")]
    for i, (m, s) in enumerate(member_mods):
        card(d, 190 + (i % 2) * 240, 218 + (i // 2) * 140, 220, 116, m, s, BLUE_L, BORDER, 16)
    zone(d, 600, 96, 1100, 470, "商品域（C-01 / C-02 / C-04 / A-01）")
    item_mods = [("分类与首页", "两级分类 · 推荐位"), ("商品 / SKU", "属性 · 价格 · 库存"),
                 ("商品审核", "待审 · 通过 · 驳回"), ("图片与详情", "图集 · 富文本")]
    for i, (m, s) in enumerate(item_mods):
        card(d, 730 + (i % 2) * 240, 218 + (i // 2) * 140, 220, 116, m, s, BLUE_L, BORDER, 16)
    zone(d, 1140, 96, 1680, 470, "治理域（A-02 / A-03 / A-05 / A-09）")
    gov_mods = [("RBAC 与数据范围", "菜单/按钮/接口/数据"), ("订单履约", "发货 · 查询 · 审计"),
                ("会员管理", "列表 · 禁用"), ("系统与任务", "参数 · 定时 · 审计")]
    for i, (m, s) in enumerate(gov_mods):
        card(d, 1270 + (i % 2) * 280, 218 + (i // 2) * 140, 260, 116, m, s, GRAY, GRAY_B, 16)

    zone(d, 60, 520, 1680, 830, "交易域（C-06 / C-07 / C-08 / B-01 / B-02）— 一期核心")
    trade = [("购物车", "加购 · 改量 · 勾选"), ("结算计价", "重算 · 运费 · 包邮"),
             ("订单", "下单 · 六页签 · 取消"), ("支付", "沙箱 · 回调 · 幂等"),
             ("库存", "原子扣减 · 回滚"), ("状态机", "迁移表 · 非法拒绝"),
             ("履约", "发货 · 确认收货"), ("幂等与重试", "clientToken · 唯一键")]
    for i, (m, s) in enumerate(trade):
        card(d, 265 + (i % 4) * 400, 620 + (i // 4) * 145, 360, 122, m, s, GREEN, GREEN_B)

    zone(d, 60, 880, 1680, 1080, "基础能力（B-03 / B-04 / B-05）— 被所有域复用")
    base = ["统一返回 / 异常 / 分页", "traceId 与日志", "Redis 缓存", "限流与防刷",
            "脱敏与审计", "OpenAPI 文档", "消息通知", "种子与可复现脚本"]
    for i, m in enumerate(base):
        card(d, 170 + i * 200, 985, 180, 118, m, "", (245, 248, 252),
             (176, 194, 214), 15)

    # dependency arrows
    for x in (310, 850, 1410):
        arrow(d, (x, 472), (x, 516), width=3, color=(90, 120, 150))
        text(d, (x + 14, 494), ("读取 / 引用", "商品与 SKU 是交易输入", "横切：权限与审计")[
            (310, 850, 1410).index(x)], font(13), fill=(90, 120, 150), anchor="lm")
    for x in (265, 865, 1465):
        arrow(d, (x, 832), (x, 876), width=3, color=(120, 140, 160))
    text(d, (885, 856), "复用：缓存 / 日志 / 幂等 / 文档 / 通知", font(13),
         fill=(120, 140, 160), anchor="lm")

    titled(img, "图 3-2 模块划分与依赖关系", W,
           "实线为业务依赖，灰线为横切与基础能力复用；模块内统一 Controller → Service → Mapper")
    save(img, "fig-3-2-modules.png")


# -------------------------------------------------------------- fig 3-3 deploy
def fig_deploy():
    W, H = 1760, 1120
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    zone(d, 60, 96, 1240, 240, "客户端（演示机浏览器）")
    card(d, 360, 175, 460, 96, "Chrome / Edge（最新两个大版本）", "管理端 + 客户前台两个标签页")
    card(d, 940, 175, 460, 96, "H5 / 小程序（目标态）", "复用同一套 /api", GRAY, GRAY_B)

    zone(d, 60, 280, 1240, 440, "前端服务（Node.js 24）")
    card(d, 330, 370, 380, 100, "admin-ui  :80", "RuoYi-Vue3 · Vite dev server")
    card(d, 810, 370, 380, 100, "user-ui  :81", "Vue3 + Vite6 + Pinia + Axios")
    card(d, 1140, 370, 150, 100, "dist/", "构建产物", GRAY, GRAY_B)

    zone(d, 60, 480, 1240, 800, "应用服务（JDK 17 · Spring Boot 4.1.0 · 单实例）")
    card(d, 650, 580, 1120, 100, "ruoyi-admin 可执行 jar  :8080",
         "ruoyi-framework · ruoyi-system · ruoyi-quartz · ruoyi-common · ruoyi-mall")
    card(d, 260, 700, 340, 100, "profile: dev / test / prod", "test 支持 1 分钟超时演示")
    card(d, 640, 700, 340, 100, "/actuator/*", "health · prometheus")
    card(d, 1020, 700, 340, 100, "/v3/api-docs · swagger-ui", "OpenAPI 契约")

    zone(d, 60, 840, 1240, 1070, "数据与文件服务（本机）")
    card(d, 260, 955, 340, 150, "MySQL 8.0.46  :3306", "pet_mall 业务库\npet_* / sys_* / qrtz_*")
    card(d, 640, 955, 340, 150, "Redis 7  :6379", "DB0 Token · DB1 缓存\n限流计数")
    card(d, 1020, 955, 340, 150, "uploadPath", "D:/ruoyi/uploadPath\n商品图 · 凭证")

    # 运维侧栏
    zone(d, 1310, 96, 1720, 1070, "交付与运维（脚本化）")
    ops = [
        ("start-all.ps1", "检查 .env / JDK / MySQL /\nRedis / 端口 → 启动后端"),
        ("stop-all.ps1", "停后端与 Redis，保留数据"),
        ("db/*.sql", "01_base · 02_pet_mall\n03_seed · rollback"),
        (".env.example", "DB_PASSWORD / JWT_SECRET\n等占位符"),
        ("README.md", "环境 · 建库 · 启动 · 账号\n演示路径"),
        ("回滚", "git tag 回退 + rollback.sql"),
    ]
    for i, (m, s) in enumerate(ops):
        card(d, 1515, 210 + i * 143, 360, 120, m, s, (245, 248, 252),
             (176, 194, 214), 16, 12)

    # arrows with protocol labels
    arrow(d, (330, 243), (330, 278), width=2, color=(90, 120, 150))
    text(d, (348, 262), "HTTP", font(13), fill=(90, 120, 150), anchor="lm")
    arrow(d, (810, 243), (810, 278), width=2, color=(90, 120, 150))
    arrow(d, (520, 443), (650, 478), width=2, color=(90, 120, 150))
    text(d, (700, 462), "HTTP /api（Vite 代理）", font(13), fill=(90, 120, 150), anchor="lm")
    for x in (260, 640, 1020):
        arrow(d, (x, 802), (x, 876), width=2, color=(90, 120, 150))
    for x, lab in ((260, "JDBC 3306"), (640, "RESP 6379"), (1020, "File IO")):
        text(d, (x + 14, 838), lab, font(13), fill=(90, 120, 150), anchor="lm")
    arrow(d, (1308, 640), (1244, 600), width=2, color=(120, 140, 160), dashed=True)
    text(d, (1276, 664), "脚本拉起", font(12), fill=(120, 140, 160))

    titled(img, "图 3-3 部署架构（单机 · 免 Docker · 脚本一键启动）", W,
           "一期单实例假设：Quartz 与本地缓存不支持多实例，演进路径见 ADR-06 / 10.5")
    save(img, "fig-3-3-deploy.png")


# ------------------------------------------------------------- fig 3-4 request
def fig_request_chain():
    W, H = 1960, 900
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    boxes = [
        ("浏览器 SPA", "Axios · Bearer Token\n统一错误码处理"),
        ("Vite Proxy", "/api → :8080\n开发期同源"),
        ("TraceIdFilter", "生成/透传 traceId\n写入 MDC 与响应头"),
        ("XSS / Repeatable", "富文本白名单\n请求体可重复读"),
        ("鉴权与限流", "JWT + @PreAuthorize\n@MemberLogin · 令牌桶"),
        ("Controller", "@Valid 参数校验\n权限码 · Idempotency-Key"),
        ("Service", "@Transactional\n业务校验 · 状态机 · 幂等"),
    ]
    bw, gap = 252, 24
    x = 50
    xs = []
    for i, (m, s) in enumerate(boxes):
        card(d, x + bw / 2, 190, bw, 168, m, s, BLUE_L if i < 5 else ACCENT,
             BORDER if i < 5 else ACCENT_B, 17, 12)
        xs.append(x + bw / 2)
        if i < len(boxes) - 1:
            arrow(d, (x + bw + 3, 190), (x + bw + gap - 3, 190), width=2)
        x += bw + gap

    # data row: Service -> Mapper -> MySQL；Service -> Redis
    card(d, 1000, 455, 340, 130, "MyBatis Mapper", "参数绑定 #{} · 分页\n禁止 ${} 拼接", GREEN, GREEN_B, 17, 12)
    card(d, 1440, 455, 340, 130, "MySQL 8 · pet_mall", "事务 · 唯一索引 · 条件更新", GREEN, GREEN_B, 17, 12)
    card(d, 1800, 455, 280, 130, "Redis 7", "Token · 缓存 · 限流", GREEN, GREEN_B, 17, 12)
    # Service -> Mapper (经由空白 lane y=360 绕行，避免穿过数据卡片)
    poly_arrow(d, [(1780, 274), (1780, 350), (1000, 350), (1000, 388)],
               width=2, color=(90, 110, 130))
    # Mapper -> MySQL
    arrow(d, (1172, 455), (1268, 455), width=2, color=(90, 110, 130))
    # Service -> Redis
    arrow(d, (1832, 278), (1832, 388), width=2, color=(90, 110, 130))

    # exception handler + unified result
    card(d, 560, 690, 620, 120, "全局异常处理器 @RestControllerAdvice",
         "业务异常 → 错误码；系统异常 → PET-5000（不暴露堆栈）", (255, 248, 235),
         (200, 160, 90), 17, 12)
    card(d, 1400, 690, 640, 120, "Result<T> { code, message, data, traceId }",
         "分页使用 PageResult；HTTP 语义 + PET-xxxx 业务码", (255, 248, 235),
         (200, 160, 90), 17, 12)
    # 任意层异常 -> 异常处理器
    poly_arrow(d, [(1004, 274), (1004, 300), (560, 300), (560, 626)],
               width=2, color=(170, 120, 60))
    text(d, (1040, 322), "任意层抛出异常", font(13), fill=(170, 120, 60), anchor="lm")
    # 正常返回 -> Result
    poly_arrow(d, [(1556, 274), (1556, 310), (1948, 310), (1948, 610),
                   (1400, 610), (1400, 628)],
               width=2, color=(170, 120, 60))
    text(d, (1610, 336), "正常返回 / 异常兜底后统一封装", font(13), fill=(170, 120, 60),
         anchor="lm")
    arrow(d, (874, 690), (1078, 690), width=2, color=(170, 120, 60))

    note = ("请求日志统一记录：traceId、memberId、URI、耗时、结果码；响应体回传 traceId；"
            "异常分支必须写业务键（orderNo / skuId / 幂等键）")
    zone(d, 60, 800, 1900, 876, "", (250, 250, 246), (220, 215, 195))
    text(d, (980, 838), note, font(15), fill=(110, 100, 70))

    titled(img, "图 3-4 请求处理链路与统一返回", W,
           "横切能力（traceId / 鉴权 / 限流 / 异常 / 返回）集中在过滤器与拦截器，业务代码不重复实现")
    save(img, "fig-3-4-chain.png")


# ----------------------------------------------------------- fig 5-1 frontend
def fig_frontend():
    W, H = 1740, 1010
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    zone(d, 50, 96, 990, 830, "user-ui（客户前台 · :81）")
    ugroups = [
        ("浏览域", ["首页", "商品列表", "搜索结果", "商品详情"], 214, 3),
        ("交易域", ["购物车", "结算页", "支付页", "支付结果", "订单列表", "订单详情"], 388, 3),
        ("会员域", ["登录/注册", "个人中心", "宠物档案", "地址管理", "消息中心"], 562, 3),
        ("其他", ["协议 / 隐私", "404 / 500"], 736, 3),
    ]
    for title, pages, y, per_row in ugroups:
        text(d, (76, y - 52), title, font(15, True), fill=NAVY, anchor="lm")
        for i, p in enumerate(pages):
            cx = 205 + (i % per_row) * 270
            cy = y + (i // per_row) * 66
            card(d, cx, cy, 240, 54, p, "", WHITE, BORDER, 14)

    zone(d, 1030, 96, 1690, 830, "admin-ui（管理后台 · :80）")
    agroups = [
        ("商品", ["商品列表", "商品编辑", "审核队列", "类目管理"], 214, 2),
        ("交易", ["订单列表", "订单详情", "发货", "库存总览", "库存流水"], 388, 2),
        ("用户与系统", ["会员列表", "会员详情", "用户/角色/菜单", "参数 / 定时任务",
                        "审计日志"], 628, 2),
    ]
    for title, pages, y, per_row in agroups:
        text(d, (1056, y - 52), title, font(15, True), fill=NAVY, anchor="lm")
        for i, p in enumerate(pages):
            cx = 1160 + (i % per_row) * 270
            cy = y + (i // per_row) * 66
            card(d, cx, cy, 240, 54, p, "", WHITE, (150, 166, 196), 14)

    zone(d, 50, 852, 1690, 990, "两端共享的前端基础层（各自工程内落地同一套规范）")
    shared = ["Axios 封装\nToken/错误码", "Pinia Store\nmember/cart/pet",
              "路由守卫\n登录回跳", "v-hasPermi\n按钮级权限",
              "公共组件\n骨架屏/空态", "格式化\n金额/时间/脱敏"]
    for i, m in enumerate(shared):
        card(d, 165 + i * 272, 937, 240, 86, m, "", (245, 248, 252), (176, 194, 214), 14)

    titled(img, "图 5-1 前端页面结构与共享层", W,
           "页面数量：客户前台 10 页 + 运营后台 8 页（对应需求文档附录 A 本期清单）")
    save(img, "fig-5-1-frontend.png")


# ------------------------------------------------------------------- fig 6-1 ER
ENTITY_FIELDS = {
    "pet_member": ("会员", ["id  PK", "username  UK", "password", "nickname",
                            "phone  UK", "status", "del_flag"], BLUE_L, BORDER),
    "pet_member_pet": ("宠物档案", ["id  PK", "member_id  FK", "name", "species",
                                    "breed", "birthday", "weight", "allergy_note"], BLUE_L, BORDER),
    "pet_address": ("收货地址", ["id  PK", "member_id  FK", "receiver", "phone",
                                 "province / city / district", "detail", "is_default"], BLUE_L, BORDER),
    "pet_message": ("消息", ["id  PK", "member_id  FK", "type", "title",
                             "read_flag", "target_url", "create_time"], BLUE_L, BORDER),
    "pet_category": ("分类", ["id  PK", "parent_id", "name", "icon",
                              "sort", "pet_scope", "status"], BLUE_L, BORDER),
    "pet_item": ("商品 SPU", ["id  PK", "category_id  FK", "merchant_id", "title",
                              "pet_species", "age_stage", "audit_status", "status",
                              "price_min"], GREEN, GREEN_B),
    "pet_item_sku": ("规格 SKU", ["id  PK", "item_id  FK", "spec_name", "price",
                                  "stock  CHECK≥0", "sku_code  UK", "status"], GREEN, GREEN_B),
    "pet_item_image": ("商品图片", ["id  PK", "item_id  FK", "url", "sort"], GREEN, GREEN_B),
    "pet_item_audit": ("审核留痕", ["id  PK", "item_id  FK", "audit_status",
                                   "auditor", "remark", "create_time"], GREEN, GREEN_B),
    "pet_cart_item": ("购物车行", ["id  PK", "member_id  FK", "item_id", "sku_id  FK",
                                  "quantity", "checked", "pet_id"], ACCENT, ACCENT_B),
    "pet_order": ("订单", ["id  PK", "order_no  UK", "member_id  FK", "merchant_id",
                           "total_amount", "freight", "pay_amount", "status",
                           "client_token  UK", "receiver_snapshot"], ACCENT, ACCENT_B),
    "pet_order_item": ("订单明细（快照）", ["id  PK", "order_id  FK", "item_id  FK",
                                           "sku_id", "title", "spec", "price",
                                           "quantity", "amount"], ACCENT, ACCENT_B),
    "pet_payment": ("支付记录", ["id  PK", "payment_no  UK", "order_no  FK",
                                 "amount", "channel", "status",
                                 "idempotency_key  UK"], ACCENT, ACCENT_B),
    "pet_stock_log": ("库存流水", ["id  PK", "sku_id  FK", "order_no",
                                   "type  DEDUCT/ROLLBACK", "change_qty",
                                   "before_qty / after_qty"], ACCENT, ACCENT_B),
}

ER_LAYOUT = {
    # key: (x1, y1, x2, y2)
    "pet_member": (100, 120, 400, 400),
    "pet_member_pet": (470, 120, 770, 400),
    "pet_address": (840, 120, 1140, 400),
    "pet_message": (1210, 120, 1510, 400),
    "pet_category": (1580, 120, 1880, 400),
    "pet_item": (100, 660, 400, 960),
    "pet_item_sku": (470, 660, 770, 960),
    "pet_item_image": (840, 660, 1140, 960),
    "pet_item_audit": (1210, 660, 1510, 960),
    "pet_cart_item": (1580, 660, 1880, 960),
    "pet_order": (180, 1080, 500, 1440),
    "pet_order_item": (600, 1080, 920, 1440),
    "pet_payment": (1020, 1080, 1340, 1440),
    "pet_stock_log": (1440, 1080, 1760, 1440),
}


def fig_er():
    W, H = 2020, 1560
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    boxes = {}
    for key, (x1, y1, x2, y2) in ER_LAYOUT.items():
        title, fields, fill, outline = ENTITY_FIELDS[key]
        draw_round(d, (x1, y1, x2, y2), 10, WHITE, outline, 2)
        d.rectangle([x1 * 2 + 2, y1 * 2 + 2, x2 * 2 - 2, (y1 + 38) * 2],
                    fill=fill, outline=outline, width=2)
        text(d, ((x1 + x2) / 2, y1 + 19), f"{title} · {key}", font(15, True), fill=NAVY)
        for i, f in enumerate(fields):
            tag = ""
            if "  " in f:
                f, tag = f.split("  ", 1)
            text(d, (x1 + 14, y1 + 58 + i * 23), f, font(13), fill=INK, anchor="lm")
            if tag:
                text(d, (x2 - 12, y1 + 58 + i * 23), tag, font(11), fill=(150, 120, 60),
                     anchor="rm")
        boxes[key] = (x1, y1, x2, y2)

    def rel_h(a, b, label="1:N"):
        ax1, ay1, ax2, ay2 = boxes[a]
        bx1, by1, bx2, by2 = boxes[b]
        y = (ay1 + ay2) / 2
        poly_arrow(d, [(ax2, y), (bx1, y)], color=(90, 105, 120), width=2)
        label_box(d, (ax2 + bx1) / 2, y - 16, label, font(12), fill=WHITE,
                  fg=(90, 105, 120))

    def poly(pts, lx, ly, label="1:N"):
        poly_arrow(d, pts, color=(90, 105, 120), width=2)
        label_box(d, lx, ly, label, font(12), fill=WHITE, fg=(90, 105, 120))

    # ---- 同排水平关系
    rel_h("pet_member", "pet_member_pet")
    rel_h("pet_item", "pet_item_sku")
    rel_h("pet_order", "pet_order_item")

    # ---- 会员 → 档案之外的子实体（从下边缘出发，走行间走廊回勾）
    poly([(150, 400), (150, 470), (990, 470), (990, 402)], 560, 452)      # → 地址
    poly([(230, 400), (230, 510), (1360, 510), (1360, 402)], 800, 492)    # → 消息
    # ---- 分类 → 商品（行间走廊，左侧下行）
    poly([(1730, 400), (1730, 550), (250, 550), (250, 658)], 1290, 532)
    # ---- 会员 → 购物车（行间走廊：从下边缘出发，避免横穿第一排实体）
    poly([(230, 400), (230, 620), (1730, 620), (1730, 658)], 900, 603)
    # ---- 商品 → 图片 / 审核留痕（第二、三排之间走廊）
    poly([(200, 960), (200, 1015), (990, 1015), (990, 962)], 600, 997)
    poly([(320, 960), (320, 1045), (1360, 1045), (1360, 962)], 800, 1027)
    # ---- SKU → 购物车（同一走廊）
    poly([(620, 960), (620, 985), (1730, 985), (1730, 962)], 1180, 967)
    # ---- 会员 → 订单（左侧留白竖线，避免穿过第二排）
    poly([(100, 260), (60, 260), (60, 1065), (340, 1065), (340, 1078)],
         200, 1065)
    # ---- 订单 → 支付 / 库存流水（第三排下方走廊）
    poly([(340, 1440), (340, 1490), (1180, 1490), (1180, 1442)], 760, 1472)
    poly([(420, 1440), (420, 1530), (1600, 1530), (1600, 1442)], 1150, 1512)
    # ---- SKU → 库存流水（右侧走廊，进入库存流水右边缘）
    poly([(700, 960), (700, 1070), (1900, 1070), (1900, 1260), (1762, 1260)],
         1500, 1052)

    titled(img, "图 6-1 一期物理数据模型（14 张业务表）", W,
           "不建物理外键，引用完整性由应用层保证；订单/明细/支付/流水只增不改，主数据软删")
    save(img, "fig-6-1-er.png")


# ------------------------------------------------------------ sequence figures
class SeqFig:
    def __init__(self, name, title, w, h, sub=None):
        self.name, self.title, self.w, self.h, self.sub = name, title, w, h, sub
        self.img = new_canvas(w, h)
        self.d = ImageDraw.Draw(self.img)
        self.lifes = {}
        self.y = 210
        self.n = 0
        self.f_label = font(14)
        self.f_sub = font(12)

    def life(self, key, x, label, sub="", fill=BLUE_L, outline=BORDER):
        bw, bh = 210, 74
        draw_round(self.d, (x - bw / 2, 104, x + bw / 2, 104 + bh), 8, fill, outline, 2)
        text(self.d, (x, 126), label, fit_font(label, bw - 18, 15, 11))
        if sub:
            text(self.d, (x, 152), sub, fit_font(sub, bw - 18, 12, 10), fill=(95, 95, 95))
        arrow(self.d, (x, 178), (x, self.h - 34), color=(160, 170, 182), width=1,
              dashed=True, head=False)
        self.lifes[key] = x

    def msg(self, a, b, label, dashed=False, dy=None):
        self.n += 1
        if dy is None:
            self.y += 52
        else:
            self.y = dy
        x1, x2 = self.lifes[a], self.lifes[b]
        color = (70, 80, 95) if not dashed else (170, 90, 90)
        arrow(self.d, (x1, self.y), (x2, self.y), color=color, width=2, dashed=dashed)
        width = abs(x2 - x1) - 26
        f = fit_font(label, max(width, 120), 14, 10)
        label_box(self.d, (x1 + x2) / 2, self.y - 17,
                  f"{self.n} {label}", f, fill=WHITE, fg=(55, 65, 80))
        return self.y

    def self_msg(self, a, label):
        self.n += 1
        self.y += 58
        x = self.lifes[a]
        poly_arrow(self.d, [(x + 4, self.y), (x + 56, self.y), (x + 56, self.y + 30),
                            (x + 6, self.y + 30)], width=2, color=(70, 80, 95))
        text(self.d, (x + 70, self.y + 15), f"{self.n} {label}", font(14),
             fill=(55, 65, 80), anchor="lm")

    def note(self, text_s, w=None):
        self.pending_note = (text_s, w)

    def save(self):
        text(self.d, (self.w / 2, 42), self.title, font(19, True), fill=NAVY)
        if self.sub:
            text(self.d, (self.w / 2, 70), self.sub, font(13), fill=(110, 110, 110))
        bottom = self.h
        pending = getattr(self, "pending_note", None)
        if pending:
            text_s, w = pending
            w = w or (self.w - 120)
            x = self.w / 2
            y = self.y + 130
            lines = text_s.split("\n")
            h = 34 + 24 * (len(lines) - 1)
            draw_round(self.d, (x - w / 2, y - h / 2, x + w / 2, y + h / 2), 8,
                       (255, 250, 236), (200, 175, 120), 1)
            for i, ln in enumerate(lines):
                text(self.d, (x, y - h / 2 + 20 + i * 24), ln,
                     fit_font(ln, w - 30, 14, 11), fill=(120, 100, 60))
            bottom = y + h / 2 + 34
        H = int(min(self.h, bottom))
        img = self.img
        if H < self.h:
            img = img.crop((0, 0, int(self.w * S), int(H * S)))
        save(img, self.name)


def fig_order_seq():
    f = SeqFig("fig-8-1-order-seq.png", "图 8-1 提交订单：事务 + 原子扣减 + 防超卖时序", 1860, 1320,
               "同一 @Transactional 内完成校验、订单、明细、扣减、流水与清购物车；任一步失败整单回滚")
    f.life("member", 150, "会员（user-ui）", "POST /api/orders")
    f.life("ctrl", 470, "OrderController", "幂等键 clientToken")
    f.life("svc", 800, "OrderService", "@Transactional")
    f.life("stock", 1100, "StockService", "原子扣减")
    f.life("cart", 1350, "CartService", "清理已结算行")
    f.life("db", 1620, "MySQL · pet_mall", "InnoDB", GREEN, GREEN_B)

    f.msg("member", "ctrl", "提交订单（地址、选中行、clientToken）")
    f.msg("ctrl", "svc", "createOrder(dto, memberId)")
    f.msg("svc", "db", "按 client_token 查已有订单（幂等预检）", dashed=True)
    f.msg("db", "svc", "命中 → 直接返回原订单（PET-4001），不再扣减", dashed=True)
    f.msg("svc", "db", "校验地址归属 + 查询勾选购物车行")
    f.self_msg("svc", "服务端重算金额（商品 + 运费 − 优惠）")
    f.self_msg("svc", "开启事务：后续步骤同生共死")
    f.msg("svc", "db", "INSERT pet_order（status=0，收货/宠物快照，expireAt）")
    f.msg("svc", "db", "INSERT pet_order_item（商品/规格/价格快照 × N）")
    f.msg("svc", "stock", "deduct(skuId, qty) 逐 SKU 执行")
    f.msg("stock", "db", "UPDATE ... SET stock=stock-? WHERE id=? AND stock>=?")
    f.msg("db", "stock", "影响行数 0 → PET-3001，事务回滚（E2）", dashed=True)
    f.msg("stock", "db", "INSERT pet_stock_log(type=DEDUCT, before/after)")
    f.msg("svc", "cart", "删除已结算购物车行")
    f.self_msg("svc", "事务提交；异常 → 整单回滚，无脏数据")
    f.msg("ctrl", "member", "返回 orderNo / payAmount / freight / expireAt")
    f.note("演示断言：库存 1、20 并发提交 → 成功 1 单、失败 19 单均返回 PET-3001；"
           "SKU.stock=0；pet_stock_log 仅 1 条 DEDUCT（对应 AC-02 / NFR-CONS-01）", 1720)
    f.save()


def fig_callback_seq():
    f = SeqFig("fig-8-2-callback-seq.png", "图 8-2 支付回调：幂等键 + 金额校验 + 状态机推进", 1860, 1220,
               "重复回调必须只生效一次：先查后插 + 唯一索引兜底，并发冲突按已成功返回")
    f.life("pay", 150, "支付沙箱 / 渠道", "Idempotency-Key")
    f.life("ctrl", 470, "PayController", "内部令牌验签")
    f.life("svc", 800, "PayService", "幂等与金额校验")
    f.life("sm", 1100, "OrderStateMachine", "0 → 2（或 0 → 1）", ACCENT, ACCENT_B)
    f.life("db", 1400, "MySQL · pet_mall", "唯一索引", GREEN, GREEN_B)
    f.life("log", 1680, "日志 / 审计", "traceId", GRAY, GRAY_B)

    f.msg("pay", "ctrl", "回调：orderNo、amount、channel、result、签名")
    f.msg("ctrl", "svc", "handleCallback(dto, idempotencyKey)")
    f.msg("svc", "db", "SELECT pet_payment WHERE idempotency_key=?")
    f.msg("db", "svc", "已存在 → duplicated=true，订单状态不变", dashed=True)
    f.msg("svc", "db", "校验订单存在（PET-4003）与金额一致（PET-4002）", dashed=True)
    f.msg("svc", "db", "INSERT pet_payment（idempotency_key UNIQUE）")
    f.msg("db", "svc", "唯一键冲突（并发重放）→ 捕获后按成功返回", dashed=True)
    f.msg("svc", "sm", "transit(orderNo, target=2, 前置 status=0)")
    f.msg("sm", "db", "UPDATE pet_order SET status=2 WHERE order_no=? AND status=0")
    f.msg("db", "sm", "影响 0 行 → 状态已推进，拒绝重复迁移")
    f.msg("sm", "db", "写 pay_time / 渠道流水号，完成状态流转日志")
    f.msg("svc", "log", "记录业务键、结果码、traceId（风险事件单独标记）")
    f.msg("ctrl", "pay", '{"code":200,"data":{"duplicated":false}}')
    f.note("演示断言：同一幂等键重放 3 次 → pet_payment 仅 1 条、订单状态只变一次、只发货一次"
           "（AC-03 / NFR-CONS-03）", 1700)
    f.save()


def fig_close_seq():
    f = SeqFig("fig-8-3-close-seq.png", "图 8-3 超时关单：条件更新 + 库存回滚 + 任务幂等", 1780, 1240,
               "Quartz 每分钟扫描（单批 ≤ 100）；单条失败不影响整批，任务可重跑且结果一致")
    f.life("job", 150, "Quartz Job", "closeTimeoutOrders")
    f.life("svc", 480, "OrderCloseService", "批量扫描 + 逐条处理")
    f.life("stock", 810, "StockService", "回滚库存")
    f.life("db", 1140, "MySQL · pet_mall", "条件更新", GREEN, GREEN_B)
    f.life("log", 1480, "任务日志 / 审计", "close_time、原因", GRAY, GRAY_B)

    f.msg("job", "svc", "触发（cron 0 * * * * ?，可手动触发）")
    f.msg("svc", "db", "SELECT id, order_no WHERE status=0 AND create_time < now()-timeout LIMIT 100")
    f.msg("db", "svc", "命中 idx_order_status_time，返回待关闭订单")
    f.self_msg("svc", "逐条处理：单条失败 catch 后继续下一条")
    f.msg("svc", "db", "UPDATE pet_order SET status=6, close_time=now() WHERE id=? AND status=0")
    f.msg("db", "svc", "影响 0 行 → 已被支付/取消，跳过", dashed=True)
    f.msg("svc", "stock", "rollback(orderNo, 明细列表)")
    f.msg("stock", "db", "UPDATE pet_item_sku SET stock=stock+? WHERE id=?")
    f.msg("stock", "db", "INSERT pet_stock_log(type=ROLLBACK)（唯一键冲突视为已回滚）")
    f.msg("svc", "db", "UPDATE pet_payment SET status='TIMEOUT'")
    f.msg("svc", "log", "写任务执行日志：扫描数 / 关闭数 / 失败数 / 耗时")
    f.note("演示断言：超时订单关闭后库存回滚、流水新增 1 条 ROLLBACK；重复执行不再回滚"
           "（AC-04 / NFR-CONS-04）", 1620)
    f.save()


if __name__ == "__main__":
    fig_arch()
    fig_modules()
    fig_deploy()
    fig_request_chain()
    fig_frontend()
    fig_er()
    fig_order_seq()
    fig_callback_seq()
    fig_close_seq()
