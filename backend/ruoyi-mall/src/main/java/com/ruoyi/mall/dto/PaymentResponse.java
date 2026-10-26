package com.ruoyi.mall.dto;

/**
 * 支付结果。
 *
 * @author ruoyi
 */
public record PaymentResponse(String paymentNo, String status, Integer orderStatus, boolean duplicated)
{
}
