package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordChangeRequest(
        @NotBlank @Size(min = 6, max = 30) String oldPassword,
        @NotBlank @Size(min = 6, max = 30) String newPassword) { }
