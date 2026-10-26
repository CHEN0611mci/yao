package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * 修改购物车数量/勾选状态。
 *
 * @author ruoyi
 */
public record CartUpdateRequest(
        @Min(1) @Max(99) Integer quantity,
        Integer checked,
        Long petId,
        Boolean clearPet
)
{
}
