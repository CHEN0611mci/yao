package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * 状态变更请求（商品上下架、会员禁用等）。
 *
 * @author ruoyi
 */
public record StatusRequest(
        @NotNull(message = "状态不能为空") @Min(0) @Max(1) Integer status
)
{
}
