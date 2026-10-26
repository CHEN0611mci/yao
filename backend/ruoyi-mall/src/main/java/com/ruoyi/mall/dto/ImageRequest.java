package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 商品图片写入项。
 *
 * @author ruoyi
 */
public record ImageRequest(Long id, @NotBlank(message = "图片地址不能为空") String url, Integer sort)
{
}
