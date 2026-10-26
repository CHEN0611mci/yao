package com.ruoyi.mall.dto;

import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 提交订单请求。
 *
 * @author ruoyi
 */
public record SubmitOrderRequest(
        @NotNull(message = "收货地址不能为空") Long addressId,
        @NotBlank(message = "clientToken不能为空") @Size(max = 64) String clientToken,
        @NotEmpty(message = "订单明细不能为空") @Valid List<@NotNull(message = "订单明细不能包含空项") OrderLineRequest> items,
        @Size(max = 200, message = "备注最多200个字符") String remark
)
{
}
