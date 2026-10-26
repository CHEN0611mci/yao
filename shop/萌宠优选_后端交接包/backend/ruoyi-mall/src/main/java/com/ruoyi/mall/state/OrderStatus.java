package com.ruoyi.mall.state;

/**
 * 订单九状态（与 SRS §4.3.1 一致）。
 *
 * @author ruoyi
 */
public enum OrderStatus
{
    PENDING_PAYMENT(0, "待付款"),
    PENDING_AUDIT(1, "待审核"),
    PENDING_SHIPMENT(2, "待发货"),
    PENDING_RECEIPT(3, "待收货"),
    COMPLETED(4, "已完成"),
    CANCELLED(5, "已取消"),
    CLOSED(6, "已关闭"),
    AFTER_SALE(7, "售后中"),
    REFUNDED(8, "已退款");

    private final int code;
    private final String label;

    OrderStatus(int code, String label)
    {
        this.code = code;
        this.label = label;
    }

    public int getCode()
    {
        return code;
    }

    public String getLabel()
    {
        return label;
    }

    public static OrderStatus of(Integer code)
    {
        if (code != null)
        {
            for (OrderStatus status : values())
            {
                if (status.code == code)
                {
                    return status;
                }
            }
        }
        return null;
    }

    public static String labelOf(Integer code)
    {
        OrderStatus status = of(code);
        return status == null ? "未知" : status.getLabel();
    }
}
