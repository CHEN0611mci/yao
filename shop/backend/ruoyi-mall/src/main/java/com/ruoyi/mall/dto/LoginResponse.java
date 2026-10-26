package com.ruoyi.mall.dto;

import com.ruoyi.mall.domain.PetMember;

/**
 * 会员登录响应。
 *
 * @author ruoyi
 */
public record LoginResponse(String token, PetMember member)
{
}
