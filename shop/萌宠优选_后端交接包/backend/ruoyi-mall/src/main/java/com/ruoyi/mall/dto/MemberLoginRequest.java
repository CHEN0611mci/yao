package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 会员登录请求。
 *
 * @author ruoyi
 */
public record MemberLoginRequest(
        @NotBlank(message = "用户名不能为空") String username,
        @NotBlank(message = "密码不能为空") String password
)
{
}
