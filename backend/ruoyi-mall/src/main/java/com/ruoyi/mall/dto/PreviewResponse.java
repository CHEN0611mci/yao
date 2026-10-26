package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * 结算试算响应。
 *
 * @author ruoyi
 */
public record PreviewResponse(List<PreviewItem> items, BigDecimal totalAmount, BigDecimal discountAmount,
        BigDecimal freight, BigDecimal payAmount, boolean freeShipping, List<String> stockWarning)
{
}
