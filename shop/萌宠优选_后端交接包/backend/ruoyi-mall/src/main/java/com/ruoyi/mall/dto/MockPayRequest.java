package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 沙箱支付请求。
 *
 * @author ruoyi
 */
public record MockPayRequest(
        @NotBlank(message = "订单号不能为空") String orderNo,
        @NotBlank(message = "支付渠道不能为空")
        @Pattern(regexp = "WECHAT|ALIPAY|BALANCE", message = "支付渠道仅支持 WECHAT/ALIPAY/BALANCE")
        String channel,
        @NotBlank(message = "支付结果不能为空")
        @Pattern(regexp = "SUCCESS|FAIL|TIMEOUT", message = "支付结果仅支持 SUCCESS/FAIL/TIMEOUT")
        String result
)
{
}
