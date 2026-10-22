package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 收货地址新增/编辑请求。
 *
 * @author ruoyi
 */
public record AddressRequest(
        @NotBlank(message = "收货人不能为空") @Size(max = 30) String receiver,
        @NotBlank(message = "联系电话不能为空")
        @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
        String phone,
        @NotBlank(message = "省份不能为空") @Size(max = 50) String province,
        @NotBlank(message = "城市不能为空") @Size(max = 50) String city,
        @NotBlank(message = "区县不能为空") @Size(max = 50) String district,
        @NotBlank(message = "详细地址不能为空") @Size(max = 200) String detail,
        Integer isDefault
)
{
}
