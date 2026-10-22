package com.ruoyi.mall.dto;

import java.util.List;

/**
 * 结算试算请求；skuIds 为空时使用购物车中已勾选且有效的行。
 *
 * @author ruoyi
 */
public record CheckoutPreviewRequest(
        List<Long> skuIds,
        Long addressId
)
{
}
