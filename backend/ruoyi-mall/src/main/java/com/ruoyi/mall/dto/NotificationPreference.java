package com.ruoyi.mall.dto;
import jakarta.validation.constraints.NotNull;
public record NotificationPreference(@NotNull Boolean orderNotifications, @NotNull Boolean systemNotifications) { }
