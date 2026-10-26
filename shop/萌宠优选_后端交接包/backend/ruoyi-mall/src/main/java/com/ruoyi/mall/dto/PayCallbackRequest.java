package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 支付回调请求；幂等键从 Idempotency-Key 请求头读取。
 *
 * @author ruoyi
 */
public record PayCallbackRequest(
        @NotBlank(message = "订单号不能为空") String orderNo,
        @NotNull(message = "金额不能为空") BigDecimal amount,
        @NotBlank(message = "支付渠道不能为空") String channel,
        @NotBlank(message = "支付结果不能为空") String result
)
{
}
