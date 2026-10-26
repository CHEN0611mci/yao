package com.ruoyi.mall.dto;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 确认收货结果。
 *
 * @author ruoyi
 */
public record ConfirmResponse(String orderNo, Integer status,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss") Date receiveTime)
{
}
