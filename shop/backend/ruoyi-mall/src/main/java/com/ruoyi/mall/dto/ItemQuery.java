package com.ruoyi.mall.dto;

import java.math.BigDecimal;

/**
 * 商品列表查询条件。
 *
 * @author ruoyi
 */
public record ItemQuery(
        String keyword,
        Long categoryId,
        String species,
        String ageStage,
        BigDecimal minPrice,
        BigDecimal maxPrice,
        String sort,
        Integer auditStatus,
        Integer status,
        Long merchantId,
        Integer pageNum,
        Integer pageSize
)
{
    public int safePageNum()
    {
        return pageNum == null || pageNum < 1 ? 1 : pageNum;
    }

    public int safePageSize()
    {
        if (pageSize == null || pageSize < 1)
        {
            return 10;
        }
        return Math.min(pageSize, 100);
    }
}
