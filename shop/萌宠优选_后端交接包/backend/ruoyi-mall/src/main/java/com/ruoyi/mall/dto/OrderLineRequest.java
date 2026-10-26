package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * 下单明细行。
 *
 * @author ruoyi
 */
public record OrderLineRequest(
        @NotNull(message = "SKU不能为空") Long skuId,
        @NotNull(message = "数量不能为空") @Min(1) @Max(99) Integer quantity,
        Long petId
)
{
}
