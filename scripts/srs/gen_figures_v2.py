# -*- coding: utf-8 -*-
"""Generate SRS V2 diagrams (flow + three state machines) reusing V1 helpers."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gen_figures import (  # noqa: E402
    Image, ImageDraw, new_canvas, draw_round, text, arrow, poly_arrow, font,
    save, NAVY, BLUE_L, BORDER, ACCENT, ACCENT_B, GREEN, GREEN_B, GRAY, GRAY_B,
    RED, RED_B, WHITE, INK, fit_font, label_box,
)

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(BASE, "docs", "01-需求文档", "images")


def titled(img, title, w):
    d = ImageDraw.Draw(img)
    text(d, (w / 2, 44), title, font(20, True), fill=NAVY)


# ------------------------------------------------------------ fig 4-1 flow v2
def fig_flow_v2():
    W, H = 1660, 1720
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    f_title = font(20, True)
    f_sub = font(18)
    f_note = font(17)
    cx, bw = 580, 620
    y = 92
    gap = 34
    steps = [
        ("首页 / 活动页（分类 · 搜索 · 推荐）", "游客可浏览，未登录加购时引导登录", GRAY, GRAY_B),
        ("商品列表（档案适配标签 · 筛选排序）", "物种 / 年龄段 / 价格 / 有货", GRAY, GRAY_B),
        ("商品详情（SKU · 库存 · 成分 · 资质）", "适配结论：适合 / 需注意 / 不适合", GRAY, GRAY_B),
        ("加入购物车（校验可售与库存）", "同 SKU 累加，上限 99 与库存", BLUE_L, BORDER),
        ("结算（地址 · 配送 · 优惠 · 发票）", "服务端试算 + 提交前二次校验", BLUE_L, BORDER),
        ("提交订单（锁库存 / 原子扣减 + 快照）", "事务内：校验 → 扣减 → 订单/明细 → 清购物车", ACCENT, ACCENT_B),
        ("支付（沙箱 / 渠道；15–30 分钟时限）", "成功 / 失败 / 超时三分支", ACCENT, ACCENT_B),
        ("支付回调（验签 + Idempotency-Key 幂等）", "重复回调只生效一次，金额必须一致", GREEN, GREEN_B),
        ("履约（拣货 · 复核 · 发货 · 物流）", "单仓发货；多仓 / 自提为二期", GREEN, GREEN_B),
        ("确认收货（或发货 10 天自动确认）", "订单完成，开放评价 30 天", GREEN, GREEN_B),
        ("评价 / 再次购买 / 申请售后", "售后进入独立状态机", GREEN, GREEN_B),
        ("完成（订阅进入下一周期，二期）", "交易闭环", GREEN, GREEN_B),
    ]
    pos = []
    for main, sub, fill, outline in steps:
        bh = 84
        draw_round(d, (cx - bw / 2, y, cx + bw / 2, y + bh), 12, fill, outline, 2)
        text(d, (cx, y + bh / 2 - 13), main, fit_font(main, bw - 34, 24, 17))
        text(d, (cx, y + bh - 19), sub, fit_font(sub, bw - 34, 17, 14), fill=(95, 95, 95))
        pos.append((y, y + bh))
        if len(pos) < len(steps):
            arrow(d, (cx, y + bh + 3), (cx, y + bh + gap - 3), width=2)
        y += bh + gap

    # right lanes
    lane_cx, lane_w = 1350, 520
    lanes = [
        (2, "处方商品分支（二期）", "上传处方 → 审核 ≤ 24h → 购买资格 30 天", RED, RED_B),
        (6, "支付异常分支", "失败可重试；超时关单回滚库存；取消回滚库存", RED, RED_B),
        (8, "履约分支（二期扩展）", "待审核订单人工审核；缺货 / 异常进异常池", RED, RED_B),
        (10, "售后分支（二期）", "申请 → 审核 → 寄回 → 验收 → 退款 / 换货", RED, RED_B),
        (11, "订阅分支（二期）", "周期到期 → 提前 3 天提醒 → 自动扣款 → 生成订单", RED, RED_B),
    ]
    for idx, main, sub, fill, outline in lanes:
        top = pos[idx][0] + 2
        draw_round(d, (lane_cx - lane_w / 2, top, lane_cx + lane_w / 2, top + 88), 10, fill, outline, 2)
        text(d, (lane_cx, top + 30), main, fit_font(main, lane_w - 40, 18, 14))
        text(d, (lane_cx, top + 62), sub, fit_font(sub, lane_w - 40, 15, 12), fill=(95, 95, 95))
        arrow(d, (cx + bw / 2 + 5, top + 44), (lane_cx - lane_w / 2 - 5, top + 44),
              color=RED_B, dashed=True, width=2)
    text(d, (lane_cx, pos[2][0] - 22), "分支与延伸流程", font(17, True), fill=RED_B)

    # phase bands
    bands = [
        (pos[0][0] - 6, pos[2][1] + 6, "浏览\n与决策"),
        (pos[3][0] - 6, pos[4][1] + 6, "购物车\n与结算"),
        (pos[5][0] - 6, pos[6][1] + 6, "下单\n与支付"),
        (pos[7][0] - 6, pos[8][1] + 6, "回调\n与履约"),
        (pos[9][0] - 6, pos[11][1] + 6, "完成\n与延伸"),
    ]
    for y1, y2, label in bands:
        draw_round(d, (60, y1, 232, y2), 8, (246, 248, 251), (190, 205, 220), 1)
        text(d, (146, (y1 + y2) / 2), label, f_note, fill=NAVY)

    titled(img, "业务全景流程图（主链路 + 分支与延伸）", W)
    save(img, "fig-4-1-flow-v2.png")



# ------------------------------------------------------------ state figures
STYLE = {
    "wait": (ACCENT, ACCENT_B),
    "progress": (BLUE_L, BORDER),
    "success": (GREEN, GREEN_B),
    "terminal": (GRAY, GRAY_B),
    "error": (RED, RED_B),
}


class StateFig:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h = name, title, w, h
        self.img = new_canvas(w, h)
        self.d = ImageDraw.Draw(self.img)
        self.states = {}
        self.f_state = font(24)
        self.f_code = font(17)
        self.f_edge = font(17)

    def state(self, key, cx, cy, code, label, kind="progress"):
        fill, outline = STYLE[kind]
        w, h = 220, 96
        draw_round(self.d, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 22, fill, outline, 2)
        text(self.d, (cx, cy - 14), label, self.f_state)
        text(self.d, (cx, cy + 22), code, self.f_code, fill=(80, 80, 80))
        self.states[key] = (cx, cy)

    def edge(self, pts, label="", at=None, dashed=False):
        color = RED_B if dashed else (60, 60, 60)
        poly_arrow(self.d, pts, color=color, width=2, head=True)
        if dashed:
            # redraw dashed look over the polyline
            for i in range(len(pts) - 1):
                arrow(self.d, pts[i], pts[i + 1], color=color, width=2, dashed=True, head=False)
        if label and at:
            label_box(self.d, at[0], at[1], label, self.f_edge, fill=WHITE, fg=(70, 70, 70))

    def save(self):
        text(self.d, (self.w / 2, 44), self.title, font(20, True), fill=NAVY)
        save(self.img, self.name)


def fig_order_state():
    f = StateFig("fig-4-2-order-state.png", "订单状态机（9 状态）", 1740, 900)
    f.state("s0", 180, 210, "status = 0", "待付款", "wait")
    f.state("s1", 540, 210, "status = 1", "待审核", "progress")
    f.state("s2", 900, 210, "status = 2", "待发货", "progress")
    f.state("s3", 1260, 210, "status = 3", "待收货", "progress")
    f.state("s4", 1620, 210, "status = 4", "已完成", "success")
    f.state("s5", 180, 650, "status = 5", "已取消", "terminal")
    f.state("s6", 520, 650, "status = 6", "已关闭", "terminal")
    f.state("s7", 1000, 650, "status = 7", "售后中", "error")
    f.state("s8", 1400, 650, "status = 8", "已退款", "terminal")

    f.edge([(290, 210), (430, 210)], "支付成功", (360, 182))
    f.edge([(650, 210), (790, 210)], "审核通过", (720, 182))
    f.edge([(1010, 210), (1150, 210)], "发货", (1080, 182))
    f.edge([(1370, 210), (1510, 210)], "确认收货", (1440, 182))
    f.edge([(150, 258), (150, 602)], "用户取消", (255, 430), dashed=True)
    f.edge([(220, 258), (220, 450), (470, 450), (470, 602)], "超时关单", (345, 423), dashed=True)
    f.edge([(540, 258), (540, 500), (210, 500), (210, 602)], "审核驳回", (375, 473), dashed=True)
    f.edge([(1260, 258), (1260, 470), (1060, 470), (1060, 602)], "申请售后", (1160, 443))
    f.edge([(1620, 258), (1620, 540), (940, 540), (940, 602)], "售后期内申请", (1290, 513))
    f.edge([(1110, 650), (1160, 650), (1160, 560), (1700, 560), (1700, 350), (1660, 350), (1660, 258)],
           "售后关闭", (1430, 533))
    f.edge([(1110, 650), (1290, 650)], "退款完成", (1200, 622))
    f.save()


def fig_aftersale_state():
    f = StateFig("fig-4-3-aftersale-state.png", "售后状态机（二期）", 1500, 1000)
    f.state("s0", 180, 200, "status = 0", "待审核", "wait")
    f.state("s1", 540, 200, "status = 1", "待寄回", "progress")
    f.state("s2", 900, 200, "status = 2", "已寄回", "progress")
    f.state("s3", 1240, 200, "status = 3", "验收中", "progress")
    f.state("s7", 180, 620, "status = 7", "已驳回", "terminal")
    f.state("s4", 540, 620, "status = 4", "退款中", "wait")
    f.state("s5", 1240, 620, "status = 5", "换货发货", "progress")
    f.state("s6", 860, 880, "status = 6", "已完成", "success")

    f.edge([(290, 200), (430, 200)], "通过（退换）", (360, 172))
    f.edge([(650, 200), (790, 200)], "寄回 / 取件", (720, 172))
    f.edge([(1010, 200), (1130, 200)], "仓库收货", (1070, 172))
    f.edge([(180, 248), (180, 572)], "审核驳回", (300, 415), dashed=True)
    f.edge([(240, 248), (240, 430), (480, 430), (480, 572)], "仅退款", (360, 403))
    f.edge([(1180, 248), (1180, 520), (600, 520), (600, 572)], "合格退款", (890, 493))
    f.edge([(1300, 248), (1300, 572)], "合格换货", (1398, 415))
    f.edge([(1120, 248), (1120, 460), (280, 460), (280, 572)], "质检不合格", (700, 433), dashed=True)
    f.edge([(540, 668), (540, 780), (820, 780), (820, 832)], "退款成功", (680, 752))
    f.edge([(1240, 668), (1240, 780), (900, 780), (900, 832)], "换货签收", (1080, 752))
    f.save()


def fig_subscription_state():
    f = StateFig("fig-4-4-subscription-state.png", "订阅状态机（二期）", 1500, 840)
    f.state("s0", 180, 260, "status = 0", "待生效", "wait")
    f.state("s1", 520, 260, "status = 1", "生效中", "progress")
    f.state("s2", 860, 260, "status = 2", "扣款中", "wait")
    f.state("s3", 1200, 260, "status = 3", "扣款失败", "error")
    f.state("s5", 520, 620, "status = 5", "已取消", "terminal")
    f.state("s4", 860, 620, "status = 4", "暂停", "terminal")
    f.state("s6", 1200, 620, "status = 6", "已结束", "terminal")

    f.edge([(290, 260), (410, 260)], "首单成功", (350, 232))
    f.edge([(630, 260), (750, 260)], "到期扣款", (690, 232))
    f.edge([(860, 308), (860, 390), (560, 390), (560, 308)], "扣款成功", (710, 365))
    f.edge([(970, 260), (1090, 260)], "扣款失败", (1030, 232))
    f.edge([(1200, 212), (1200, 150), (800, 150), (800, 212)], "重试 1/3/5 天", (1000, 126))
    f.edge([(1200, 308), (1200, 460), (890, 460), (890, 572)], "3 次失败暂停", (1050, 435))
    f.edge([(520, 308), (520, 460), (830, 460), (830, 572)], "用户暂停", (665, 435))
    f.edge([(860, 572), (860, 520), (480, 520), (480, 308)], "用户恢复", (670, 495))
    f.edge([(410, 260), (370, 260), (370, 620), (410, 620)], "用户取消", (300, 440))
    f.edge([(750, 620), (630, 620)], "用户取消", (690, 592))
    f.edge([(520, 212), (520, 120), (1420, 120), (1420, 620), (1310, 620)], "商品下架 / 不可订阅", (900, 96))
    f.save()


if __name__ == "__main__":
    fig_flow_v2()
    fig_order_state()
    fig_aftersale_state()
    fig_subscription_state()
