package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 商品 SKU 写入项。
 *
 * @author ruoyi
 */
public record SkuRequest(
        Long id,
        @NotBlank(message = "规格名不能为空") String specName,
        @NotNull(message = "价格不能为空") @DecimalMin(value = "0.01", message = "价格必须大于0") BigDecimal price,
        @NotNull(message = "库存不能为空") @Min(value = 0, message = "库存不能为负") Integer stock,
        String skuCode,
        String image,
        Integer status
)
{
}
