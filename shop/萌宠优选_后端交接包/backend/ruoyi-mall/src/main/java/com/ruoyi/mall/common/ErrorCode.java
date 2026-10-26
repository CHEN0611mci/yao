package com.ruoyi.mall.common;

/**
 * 商城业务错误码（与设计文档 §7.3 一致）。
 *
 * @author ruoyi
 */
public enum ErrorCode
{
    PET_1001(1001, 400, "参数缺失或格式错误"),
    PET_1002(1002, 400, "数据已存在"),
    PET_1003(1003, 400, "数据被引用，无法删除"),
    PET_1004(1004, 400, "已达数量上限"),
    PET_1005(1005, 400, "回调令牌校验失败"),
    PET_2001(2001, 401, "未登录或登录已失效"),
    PET_2002(2002, 401, "账号或密码错误"),
    PET_2003(2003, 403, "无权访问该数据"),
    PET_2004(2004, 403, "账号已被禁用"),
    PET_3001(3001, 409, "库存不足"),
    PET_3002(3002, 409, "订单状态不允许该操作"),
    PET_3003(3003, 400, "商品不可售"),
    PET_3004(3004, 400, "收货地址无效"),
    PET_3005(3005, 400, "超过限购数量"),
    PET_4001(4001, 200, "重复请求，已返回原结果"),
    PET_4002(4002, 400, "回调金额不一致"),
    PET_4003(4003, 404, "订单不存在"),
    PET_4004(4004, 409, "售后条件不满足"),
    PET_4005(4005, 409, "退款超上限"),
    PET_4290(4290, 429, "请求过于频繁，请稍后再试"),
    PET_5000(5000, 500, "系统繁忙，请稍后再试"),
    PET_5001(5001, 500, "数据库操作失败，请稍后再试"),
    PET_5002(5002, 503, "缓存服务不可用"),
    PET_6001(6001, 400, "文件类型或大小不支持"),
    PET_7001(7001, 400, "商品命中禁售规则"),
    PET_7002(7002, 403, "处方资格无效");

    private final int code;
    private final int httpStatus;
    private final String message;

    ErrorCode(int code, int httpStatus, String message)
    {
        this.code = code;
        this.httpStatus = httpStatus;
        this.message = message;
    }

    public int getCode()
    {
        return code;
    }

    public int getHttpStatus()
    {
        return httpStatus;
    }

    public String getMessage()
    {
        return message;
    }

    public String getCodeText()
    {
        return "PET-" + code;
    }

    public static ErrorCode of(int code)
    {
        for (ErrorCode value : values())
        {
            if (value.code == code)
            {
                return value;
            }
        }
        return PET_5000;
    }
}
