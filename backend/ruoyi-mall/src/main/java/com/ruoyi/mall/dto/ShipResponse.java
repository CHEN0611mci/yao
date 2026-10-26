package com.ruoyi.mall.dto;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 发货结果。
 *
 * @author ruoyi
 */
public record ShipResponse(String orderNo, Integer status,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss") Date shipTime,
        String company, String trackingNo)
{
}
