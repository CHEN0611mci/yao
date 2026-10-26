package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 发货请求。
 *
 * @author ruoyi
 */
public record ShipRequest(
        @NotBlank(message = "物流公司不能为空") @Size(max = 50) String company,
        @NotBlank(message = "运单号不能为空") @Size(max = 50) String trackingNo
)
{
}
