package com.ruoyi.mall.dto;

import java.math.BigDecimal;

/**
 * 结算/订单明细展示项。
 *
 * @author ruoyi
 */
public record PreviewItem(Long skuId, Long itemId, String title, String spec, BigDecimal price,
        Integer quantity, BigDecimal amount, String petName, String image)
{
}
