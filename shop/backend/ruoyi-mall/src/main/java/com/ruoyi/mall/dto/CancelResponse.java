package com.ruoyi.mall.dto;

/**
 * 取消订单结果。
 *
 * @author ruoyi
 */
public record CancelResponse(String orderNo, Integer status, boolean stockRolledBack)
{
}
