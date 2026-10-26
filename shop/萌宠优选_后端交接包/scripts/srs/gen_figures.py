# -*- coding: utf-8 -*-
"""Generate SRS diagrams (PNG) for the pet mall requirements document."""
import math
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(BASE, "docs", "01-需求文档", "images")
os.makedirs(OUT, exist_ok=True)

S = 2
FONT_R = r"C:\Windows\Fonts\msyh.ttc"
FONT_B = r"C:\Windows\Fonts\msyhbd.ttc"

INK = (26, 26, 26)
NAVY = (31, 78, 121)
BLUE_L = (235, 242, 250)
BORDER = (140, 166, 196)
ACCENT = (255, 242, 204)
ACCENT_B = (191, 144, 0)
GREEN = (226, 239, 218)
GREEN_B = (84, 130, 53)
GRAY = (243, 243, 243)
GRAY_B = (150, 150, 150)
RED = (250, 230, 230)
RED_B = (180, 70, 70)
WHITE = (255, 255, 255)


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT_R, size * S)


def new_canvas(w, h, bg=WHITE):
    return Image.new("RGB", (w * S, h * S), bg)


def draw_round(d, xy, radius, fill, outline, width=2):
    d.rounded_rectangle([v * S for v in xy], radius=radius * S, fill=fill,
                        outline=outline, width=width * S)


def text(d, xy, s, f, fill=INK, anchor="mm", spacing=5):
    x, y = xy[0] * S, xy[1] * S
    lines = s.split("\n")
    bbs = [f.getbbox(ln) for ln in lines]
    line_h = max(b - t for _, t, _, b in bbs) + spacing * S
    total = line_h * len(lines)
    start = y - total / 2 + line_h / 2
    for i, ln in enumerate(lines):
        d.text((x, start + i * line_h), ln, font=f, fill=fill, anchor=anchor)
    return max(f.getlength(ln) / S for ln in lines)


def arrow(d, p1, p2, color=(64, 64, 64), width=2, dashed=False, head=True, head_size=9):
    x1, y1 = p1[0] * S, p1[1] * S
    x2, y2 = p2[0] * S, p2[1] * S
    dx, dy = x2 - x1, y2 - y1
    dist = math.hypot(dx, dy)
    if dist == 0:
        return
    if dashed:
        step, on = 12 * S, 7 * S
        n = int(dist // step) + 1
        for i in range(n):
            a = i * step
            b = min(a + on, dist)
            if a >= dist:
                break
            d.line([x1 + dx * a / dist, y1 + dy * a / dist,
                    x1 + dx * b / dist, y1 + dy * b / dist], fill=color, width=width * S)
    else:
        d.line([x1, y1, x2, y2], fill=color, width=width * S)
    if head:
        ang = math.atan2(dy, dx)
        hs = head_size * S
        left = (x2 - hs * math.cos(ang - 0.42), y2 - hs * math.sin(ang - 0.42))
        right = (x2 - hs * math.cos(ang + 0.42), y2 - hs * math.sin(ang + 0.42))
        d.polygon([(x2, y2), left, right], fill=color)


def poly_arrow(d, pts, color=(64, 64, 64), width=2, head=True):
    for i in range(len(pts) - 2):
        arrow(d, pts[i], pts[i + 1], color=color, width=width, head=False)
    arrow(d, pts[-2], pts[-1], color=color, width=width, head=head)


def fit_font(s, max_w, base=25, floor=15, bold=False):
    for size in range(base, floor - 1, -1):
        f = font(size, bold)
        if max(f.getlength(ln) / S for ln in s.split("\n")) <= max_w:
            return f
    return font(floor, bold)


def wrap_text(s, f, max_w):
    lines, cur = [], ""
    for ch in s:
        if f.getlength(cur + ch) / S > max_w and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def label_box(d, cx, cy, s, f, fill=(255, 255, 255), fg=(70, 70, 70)):
    w = f.getlength(s) / S
    h = (f.getbbox("中")[3] - f.getbbox("中")[1]) / S + 8
    d.rectangle([(cx - w / 2 - 6) * S, (cy - h / 2) * S,
                 (cx + w / 2 + 6) * S, (cy + h / 2) * S], fill=fill)
    d.text((cx * S, cy * S), s, font=f, fill=fg, anchor="mm")


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    print("saved", path, img.size)


# ---------------------------------------------------------------- fig 4-1 flow
def fig_flow():
    W, H = 1760, 1700
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_sub = font(18)
    f_note = font(17)
    cx, bw = 640, 660
    y = 96
    gap = 38
    steps = [
        ("游客浏览首页 / 分类 / 搜索商品", "匿名可访问", GRAY, GRAY_B),
        ("商品详情（价格、SKU、库存、适用性提示）", "未登录仅提示建档，不拦截", GRAY, GRAY_B),
        ("注册 / 登录（会员 Token）", "Redis 存储，7 天有效", BLUE_L, BORDER),
        ("维护宠物档案 → 选择收货地址", "档案驱动选购", BLUE_L, BORDER),
        ("加入购物车（校验可售与库存）", "唯一 (member_id, sku_id)", BLUE_L, BORDER),
        ("勾选结算 → 提交订单", "服务端重算金额，不信任前端", ACCENT, ACCENT_B),
        ("事务内：校验 → 原子扣库存 → 写订单/明细\n→ 清购物车 → 写库存流水", "同一 @Transactional(rollbackFor=Exception.class)", ACCENT, ACCENT_B),
        ("沙箱支付（成功 / 失败 / 超时）", "15 分钟支付时限", ACCENT, ACCENT_B),
        ("支付回调（Idempotency-Key 幂等）", "重复回调只生效一次", GREEN, GREEN_B),
        ("商家发货", "订单 → 待收货", GREEN, GREEN_B),
        ("会员确认收货", "订单 → 已完成", GREEN, GREEN_B),
        ("订单完成 / 评价（可选）", "交易闭环", GREEN, GREEN_B),
    ]
    pos = []
    for i, (main, sub, fill, outline) in enumerate(steps):
        n_lines = main.count("\n") + 1
        bh = 50 + 34 * n_lines
        draw_round(d, (cx - bw / 2, y, cx + bw / 2, y + bh), 12, fill, outline, 2)
        f_main = fit_font(main, bw - 36, base=24, floor=17)
        text(d, (cx, y + bh / 2 - 12), main, f_main, spacing=6)
        text(d, (cx, y + bh - 20), sub, f_sub, fill=(95, 95, 95))
        pos.append((y, y + bh))
        if i < len(steps) - 1:
            nxt = 50 + 34 * (steps[i + 1][0].count("\n") + 1)
            arrow(d, (cx, y + bh + 4), (cx, y + bh + gap - 4), width=2)
        y += bh + gap

    # exception lanes
    lane_cx, lane_w, lane_h = 1420, 460, 100
    lanes = [
        (5, "库存不足 → PET-3001", "影响行数为 0 → 整单回滚，返回缺货 SKU"),
        (7, "支付失败 / 待付款取消", "失败可重试；取消回滚库存并写 ROLLBACK 流水"),
        (8, "15 分钟未支付 → 自动关单", "Quartz 扫描 → 关闭订单 → 回滚库存 → 写流水"),
    ]
    for idx, main, sub in lanes:
        top = pos[idx][0] + 2
        draw_round(d, (lane_cx - lane_w / 2, top, lane_cx + lane_w / 2, top + lane_h), 10, RED, RED_B, 2)
        text(d, (lane_cx, top + 38), main, fit_font(main, lane_w - 36, 19, 15))
        text(d, (lane_cx, top + 72), sub, fit_font(sub, lane_w - 36, 16, 13), fill=(95, 95, 95))
        arrow(d, (cx + bw / 2 + 6, top + lane_h / 2), (lane_cx - lane_w / 2 - 6, top + lane_h / 2),
              color=RED_B, dashed=True, width=2)
    text(d, (lane_cx, pos[5][0] - 26), "异常分支（均可演示）", font(18, True), fill=RED_B)

    # phase bands
    bands = [
        (pos[0][0] - 6, pos[1][1] + 6, "浏览阶段\n（游客）"),
        (pos[2][0] - 6, pos[3][1] + 6, "决策阶段\n（会员）"),
        (pos[4][0] - 6, pos[6][1] + 6, "交易阶段\n（事务一致性）"),
        (pos[7][0] - 6, pos[8][1] + 6, "支付阶段\n（幂等）"),
        (pos[9][0] - 6, pos[11][1] + 6, "履约阶段\n（状态机）"),
    ]
    for y1, y2, label in bands:
        draw_round(d, (100, y1, 292, y2), 8, (246, 248, 251), (190, 205, 220), 1)
        text(d, (196, (y1 + y2) / 2), label, f_note, fill=NAVY)

    text(d, (880, 44), "业务主流程（含异常分支）", f_title, fill=NAVY)
    save(img, "fig-4-1-flow.png")


# ------------------------------------------------------------- fig 4-2 state
def fig_state():
    W, H = 1800, 820
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_state = font(24)
    f_code = font(18)
    f_edge = font(19)
    f_note = font(17)

    def state(cx, cy, code, label, fill, outline):
        draw_round(d, (cx - 135, cy - 56, cx + 135, cy + 56), 26, fill, outline, 2)
        text(d, (cx, cy - 17), label, f_state)
        text(d, (cx, cy + 19), code, f_code, fill=(80, 80, 80))

    state(310, 240, "status = 0", "待付款", ACCENT, ACCENT_B)
    state(780, 240, "status = 1", "待发货", BLUE_L, BORDER)
    state(1250, 240, "status = 2", "待收货", BLUE_L, BORDER)
    state(1660, 240, "status = 3", "已完成", GREEN, GREEN_B)
    state(310, 680, "status = 4", "已取消", GRAY, GRAY_B)
    state(880, 680, "status = 5", "已关闭", GRAY, GRAY_B)

    # start marker
    d.ellipse([(302) * S, (112) * S, (318) * S, (128) * S], fill=INK)
    arrow(d, (310, 130), (310, 180), width=2)
    text(d, (470, 130), "下单成功：扣库存 + DEDUCT 流水", f_note, fill=(90, 90, 90))

    arrow(d, (447, 240), (643, 240), width=2)
    text(d, (545, 208), "支付成功回调", f_edge)
    text(d, (545, 272), "幂等 + 金额校验", f_note, fill=(110, 110, 110))
    arrow(d, (917, 240), (1113, 240), width=2)
    text(d, (1015, 212), "商家发货", f_edge)
    text(d, (1015, 272), "归属校验", f_note, fill=(110, 110, 110))
    arrow(d, (1387, 240), (1523, 240), width=2)
    text(d, (1455, 212), "确认收货", f_edge)
    text(d, (1455, 272), "仅本人", f_note, fill=(110, 110, 110))

    # cancel: left arrow
    poly_arrow(d, [(270, 298), (270, 622)], width=2)
    text(d, (190, 430), "用户取消", f_edge)
    text(d, (190, 460), "回滚库存", f_note, fill=(110, 110, 110))

    # timeout: L shaped to 已关闭
    poly_arrow(d, [(350, 298), (350, 520), (880, 520), (880, 622)], width=2)
    text(d, (612, 490), "超时关单（15 分钟）", f_edge)
    text(d, (612, 552), "Quartz 扫描 + 库存回滚 + ROLLBACK 流水", f_note, fill=(110, 110, 110))

    text(d, (900, 44), "订单状态机（6 状态，非法迁移一律 PET-3002）", f_title, fill=NAVY)
    save(img, "fig-4-2-state.png")


# ------------------------------------------------------------ fig 4-3 usecase
def fig_usecase():
    W, H = 1880, 1200
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_actor = font(21, True)
    f_uc = font(19)
    f_note = font(16)

    bx1, by1, bx2, by2 = 430, 92, 1450, 1140
    d.rectangle([bx1 * S, by1 * S, bx2 * S, by2 * S], outline=NAVY, width=2 * S)
    text(d, ((bx1 + bx2) / 2, 122), "萌宠优选 · 宠物商城系统", font(20, True), fill=NAVY)

    def actor(cx, cy, label):
        d.ellipse([(cx - 22) * S, (cy - 88) * S, (cx + 22) * S, (cy - 44) * S],
                  outline=INK, width=2 * S)
        d.line([cx * S, (cy - 44) * S, cx * S, (cy + 12) * S], fill=INK, width=2 * S)
        d.line([(cx - 45) * S, (cy - 18) * S, (cx + 45) * S, (cy - 18) * S], fill=INK, width=2 * S)
        d.line([cx * S, (cy + 12) * S, (cx - 38) * S, (cy + 68) * S], fill=INK, width=2 * S)
        d.line([cx * S, (cy + 12) * S, (cx + 38) * S, (cy + 68) * S], fill=INK, width=2 * S)
        text(d, (cx, cy + 100), label, f_actor)

    def uc(cx, cy, label, fill=BLUE_L, outline=BORDER):
        w, h = 360, 82
        d.ellipse([(cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S],
                  fill=fill, outline=outline, width=2 * S)
        text(d, (cx, cy), label, fit_font(label, w - 54, 19, 14))

    actor(190, 340, "游客")
    actor(190, 850, "会员")
    actor(1690, 420, "商家")
    actor(1690, 900, "管理员")

    col1, col2 = 760, 1180
    left = [
        ("UC-04 浏览首页 / 分类", 210, GRAY, GRAY_B),
        ("UC-05 搜索与筛选商品", 340, GRAY, GRAY_B),
        ("UC-06 查看商品详情", 470, GRAY, GRAY_B),
        ("UC-01 注册 / UC-02 登录", 600, WHITE, BORDER),
        ("UC-08 宠物档案与适用性", 730, ACCENT, ACCENT_B),
        ("UC-10 管理购物车", 860, BLUE_L, BORDER),
        ("UC-11 提交订单（防超卖）", 990, ACCENT, ACCENT_B),
    ]
    right = [
        ("UC-12 沙箱支付", 210, BLUE_L, BORDER),
        ("UC-14 我的订单 / 取消 / 收货", 340, BLUE_L, BORDER),
        ("UC-21 发布与维护商品", 470, GREEN, GREEN_B),
        ("UC-22 上下架 / UC-24 发货", 600, GREEN, GREEN_B),
        ("UC-25 商品审核", 730, ACCENT, ACCENT_B),
        ("UC-26~28 分类 / 会员 / 订单管理", 860, ACCENT, ACCENT_B),
        ("UC-29 审计日志 / 系统管理", 990, ACCENT, ACCENT_B),
    ]
    for label, cy, fill, outline in left:
        uc(col1, cy, label, fill, outline)
    for label, cy, fill, outline in right:
        uc(col2, cy, label, fill, outline)

    # relations
    for cy in (210, 340, 470):
        arrow(d, (200, 320), (col1 - 186, cy), color=(70, 70, 70), width=1, head=False)
    for cy in (470, 600, 730, 860, 990):
        arrow(d, (200, 830), (col1 - 186, cy), color=(70, 70, 70), width=1, head=False)
    for cy in (210, 340, 470, 600):
        arrow(d, (1690, 400), (col2 + 186, cy), color=(70, 70, 70), width=1, head=False)
    for cy in (730, 860, 990):
        arrow(d, (1690, 880), (col2 + 186, cy), color=(70, 70, 70), width=1, head=False)

    text(d, (940, 55), "系统用例图（4 个参与者，按最小权限裁剪）", f_title, fill=NAVY)
    text(d, (940, 1120), "注：会员继承游客全部用例；商家与管理员共用后台登录入口，按权限码裁剪菜单与按钮。",
         f_note, fill=(90, 90, 90))
    save(img, "fig-4-3-usecase.png")


# --------------------------------------------------------------- fig 4-4 seq
def fig_seq():
    W, H = 2120, 1250
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_life = font(20, True)
    f_msg = font(18)
    f_note = font(16)

    lifes = [("前端 / 会员", 210), ("订单服务", 650), ("支付服务", 1090),
             ("数据库", 1530), ("定时任务 Quartz", 1920)]
    for label, cx in lifes:
        draw_round(d, (cx - 135, 112, cx + 135, 176), 10, NAVY, NAVY, 2)
        text(d, (cx, 144), label, f_life, fill=WHITE)
        arrow(d, (cx, 180), (cx, 1155), color=(170, 170, 170), width=2, dashed=True, head=False)

    def msg(y, x1, x2, label, color=(50, 50, 50), dashed=False):
        arrow(d, (x1, y), (x2, y), color=color, width=2, dashed=dashed)
        mid = (x1 + x2) / 2
        lines = wrap_text(label, f_msg, 740)
        start_y = y - 20 - 26 * (len(lines) - 1)
        for i, ln in enumerate(lines):
            label_box(d, mid, start_y + i * 26, ln, f_msg, fill=WHITE, fg=color)

    def self_msg(y, cx, label):
        poly_arrow(d, [(cx, y), (cx + 104, y), (cx + 104, y + 50), (cx + 10, y + 50)],
                   color=(50, 50, 50))
        lines = wrap_text(label, f_msg, 560)
        for i, ln in enumerate(lines):
            w = f_msg.getlength(ln) / S
            d.rectangle([(cx + 16) * S, (y + 74 + i * 26 - 13) * S,
                         (cx + 22 + w) * S, (y + 74 + i * 26 + 13) * S], fill=WHITE)
            text(d, (cx + 20, y + 74 + i * 26), ln, f_msg, fill=(50, 50, 50), anchor="lm")

    y = 250
    msg(y, 210, 650, "① POST /api/pay/mock（orderNo、channel、result）")
    y += 92
    msg(y, 650, 1090, "② 校验订单可支付 → 请求沙箱支付")
    y += 92
    msg(y, 1090, 1530, "③ INSERT pet_payment（idempotency_key 唯一）")
    y += 92
    msg(y, 1090, 650, "④ POST /api/pay/callback（Idempotency-Key + SUCCESS + amount）", color=NAVY)
    y += 92
    msg(y, 650, 1530, "⑤ 金额一致 → UPDATE pet_order SET status=1 WHERE status=0")
    y += 92
    msg(y, 1090, 650, "⑥ 重放同一回调 ×2", color=RED_B, dashed=True)
    y += 92
    self_msg(y, 650, "⑦ 唯一键冲突 → 返回 duplicated=true，订单状态不变")
    y += 158
    msg(y, 1920, 1530, "⑧ 每分钟扫描 status=0 且已超时订单（≤100 条/批）", color=GREEN_B)
    y += 100
    msg(y, 1920, 1530, "⑨ 条件更新 status=5 → stock=stock+qty → 写 ROLLBACK 流水", color=GREEN_B)
    y += 100
    msg(y, 1530, 210, "⑩ 会员端订单页刷新为「已关闭」，库存恢复可售", color=(100, 100, 100), dashed=True)

    text(d, (1060, 1215),
         "说明：③~⑦ 为幂等区间（重复回调不产生第二次状态变更）；⑤ 保证支付与订单状态同向推进；"
         "⑧~⑨ 通过条件更新与流水唯一键保证库存只回滚一次。",
         f_note, fill=(90, 90, 90))

    text(d, (1060, 55), "支付回调幂等与超时关单时序（异常路径同样可控）", f_title, fill=NAVY)
    save(img, "fig-4-4-seq.png")


# ----------------------------------------------------------------- fig 6-1 ER
def fig_er():
    W, H = 1880, 1290
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_ent = font(20, True)
    f_field = font(16)
    f_rel = font(15)

    def entity(cx, cy, name, fields, fill=BLUE_L, outline=BORDER, w=300):
        h = 54 + 29 * len(fields)
        x1, y1, x2, y2 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
        draw_round(d, (x1, y1, x2, y2), 8, fill, outline, 2)
        d.rectangle([(x1 + 2) * S, (y1 + 2) * S, (x2 - 2) * S, (y1 + 46) * S], fill=outline)
        text(d, (cx, y1 + 25), name, f_ent, fill=WHITE)
        for i, fd in enumerate(fields):
            text(d, (x1 + 14, y1 + 68 + i * 29), fd, f_field, fill=(40, 40, 40), anchor="lm")
        return (x1, y1, x2, y2)

    def rel(b1, b2, card="1:N", p1=None, p2=None):
        c1 = ((b1[0] + b1[2]) / 2, (b1[1] + b1[3]) / 2)
        c2 = ((b2[0] + b2[2]) / 2, (b2[1] + b2[3]) / 2)

        def edge(box, toward, prefer):
            cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
            dx, dy = toward[0] - cx, toward[1] - cy
            if abs(dx) < 1:
                return (cx, box[3] if dy > 0 else box[1])
            slope = dy / dx
            tx = box[2] if dx > 0 else box[0]
            ty = cy + slope * (tx - cx)
            if ty < box[1] or ty > box[3]:
                ty = box[3] if dy > 0 else box[1]
                tx = cx + (ty - cy) / slope if slope else cx
            return (tx, ty)

        a = p1 or edge(b1, c2, None)
        b = p2 or edge(b2, c1, None)
        arrow(d, a, b, color=(120, 140, 165), width=2, head=False)
        d.ellipse([a[0] * S - 3 * S, a[1] * S - 3 * S, a[0] * S + 3 * S, a[1] * S + 3 * S], fill=NAVY)
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        label_box(d, mx, my, card, f_rel, fill=WHITE, fg=(90, 100, 115))

    member = entity(300, 210, "pet_member 会员",
                    ["id PK", "username UNIQUE", "password BCrypt", "phone / status"])
    order = entity(300, 620, "pet_order 订单",
                   ["id PK", "order_no UNIQUE", "member_id / merchant_id", "pay_amount / status",
                    "receiver_snapshot"], fill=ACCENT, outline=ACCENT_B)
    pay = entity(300, 950, "pet_payment 支付单",
                 ["id PK", "order_no FK", "amount / channel / status",
                  "idempotency_key UNIQUE"], fill=ACCENT, outline=ACCENT_B)

    pet = entity(770, 180, "pet_member_pet 宠物档案",
                 ["id PK", "member_id FK", "species / birthday", "weight / sterilized"])
    addr = entity(770, 390, "pet_address 地址",
                  ["id PK", "member_id FK", "receiver / phone", "is_default"])
    cart = entity(770, 600, "pet_cart_item 购物车",
                  ["id PK", "member_id FK / sku_id", "quantity / checked",
                   "UNIQUE(member_id, sku_id)"])
    oitem = entity(770, 900, "pet_order_item 明细",
                   ["id PK", "order_id FK", "item_id / sku_id",
                    "title / spec / price / qty"])
    stock = entity(770, 1120, "pet_stock_log 库存流水",
                   ["id PK", "sku_id / order_no", "type / change_qty",
                    "before_qty / after_qty"], fill=ACCENT, outline=ACCENT_B)

    item = entity(1220, 180, "pet_item 商品",
                  ["id PK", "category_id FK", "merchant_id 归属",
                   "pet_species / age_stage", "audit_status / status"],
                  fill=(247, 250, 253), outline=BORDER)
    sku = entity(1220, 430, "pet_item_sku SKU",
                 ["id PK", "item_id FK", "price / stock CHECK≥0",
                  "sku_code UNIQUE"], fill=(247, 250, 253), outline=BORDER)

    cat = entity(1620, 180, "pet_category 分类",
                 ["id PK", "parent_id 自关联", "name / icon / sort",
                  "pet_scope / status"])
    audit = entity(1620, 430, "pet_item_audit 审核留痕",
                   ["id PK", "item_id FK", "audit_status / auditor",
                    "remark / create_time"])

    rel(member, pet, "1:N")
    rel(member, addr, "1:N")
    rel(member, cart, "1:N")
    rel(member, order, "1:N")
    rel(order, pay, "1:N")
    rel(order, oitem, "1:N")
    rel(order, stock, "1:N")
    rel(cat, item, "1:N")
    rel(item, sku, "1:N")
    rel(item, audit, "1:N")
    rel(sku, stock, "1:N")
    rel(sku, cart, "1:N")

    draw_round(d, (1090, 1120, 1790, 1260), 8, (250, 250, 250), (205, 205, 205), 1)
    text(d, (1440, 1148), "图例：PK 主键 / FK 逻辑外键 / UNIQUE 唯一约束", f_rel, fill=(80, 80, 80))
    text(d, (1440, 1178), "黄色为交易域，与库存流水共同保证一致性；", f_rel, fill=(80, 80, 80))
    text(d, (1440, 1208), "物理外键不建，由应用层保证引用完整性。", f_rel, fill=(80, 80, 80))

    text(d, (940, 52), "领域模型与 ER 图（12 个核心实体，系统表 sys_* 复用）", f_title, fill=NAVY)
    save(img, "fig-6-1-er.png")


if __name__ == "__main__":
    fig_flow()
    fig_state()
    fig_usecase()
    fig_seq()
    fig_er()
