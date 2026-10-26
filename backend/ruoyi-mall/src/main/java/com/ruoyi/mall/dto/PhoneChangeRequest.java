package com.ruoyi.mall.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
public record PhoneChangeRequest(
        @NotBlank @Pattern(regexp="^1[3-9]\\d{9}$", message="请输入有效的联系手机号") String phone,
        @NotBlank @Size(min=6,max=30) String password) { }
