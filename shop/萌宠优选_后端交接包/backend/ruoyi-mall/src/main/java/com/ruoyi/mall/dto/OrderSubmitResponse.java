package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 提交订单响应。
 *
 * @author ruoyi
 */
public record OrderSubmitResponse(
        String orderNo,
        BigDecimal payAmount,
        BigDecimal freight,
        Integer status,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss") Date expireAt,
        boolean duplicated
)
{
}
