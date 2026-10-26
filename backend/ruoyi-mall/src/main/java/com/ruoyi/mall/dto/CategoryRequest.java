package com.ruoyi.mall.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 分类新增/编辑请求。
 *
 * @author ruoyi
 */
public record CategoryRequest(
        Long parentId,
        @NotBlank(message = "分类名不能为空") @Size(max = 50) String name,
        String icon,
        Integer sort,
        @Pattern(regexp = "^$|CAT|DOG|SMALL|ALL", message = "宠物范围仅支持 CAT/DOG/SMALL/ALL")
        String petScope,
        Integer status
)
{
}
