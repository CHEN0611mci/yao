package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 库存人工调整请求：直接指定调整后的目标库存。
 *
 * @author ruoyi
 */
public record StockAdjustRequest(
        @NotNull(message = "目标库存不能为空")
        @Min(value = 0, message = "目标库存不能为负数")
        Integer targetStock,

        @Size(max = 200, message = "备注最多200个字符")
        String remark
)
{
}
