package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Size;

/**
 * 取消订单请求；原因可为空。
 *
 * @author ruoyi
 */
public record CancelRequest(
        @Size(max = 200, message = "取消原因最多200个字符") String reason
)
{
}
