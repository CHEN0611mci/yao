package com.ruoyi.mall.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record FeedbackRequest(@NotBlank @Size(min = 5, max = 1000) String content) { }
