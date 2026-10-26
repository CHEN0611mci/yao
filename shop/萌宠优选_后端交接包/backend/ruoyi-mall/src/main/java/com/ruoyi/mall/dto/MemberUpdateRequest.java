package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 会员资料修改请求。
 *
 * @author ruoyi
 */
public record MemberUpdateRequest(
        @NotBlank(message = "昵称不能为空")
        @Size(max = 30, message = "昵称最多30个字符")
        String nickname,
        @Size(max = 255, message = "头像地址过长")
        String avatar
)
{
}
