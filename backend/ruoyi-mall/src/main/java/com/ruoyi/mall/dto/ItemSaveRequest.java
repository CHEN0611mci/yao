package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 商品发布/编辑请求。
 *
 * @author ruoyi
 */
public record ItemSaveRequest(
        Long merchantId,
        @NotNull(message = "分类不能为空") Long categoryId,
        @NotBlank(message = "商品标题不能为空") @Size(max = 100) String title,
        @Size(max = 200) String subtitle,
        @NotBlank(message = "主图不能为空") String mainImage,
        @Size(max = 50) String brand,
        @NotBlank(message = "适用物种不能为空")
        @Pattern(regexp = "CAT|DOG|SMALL|ALL", message = "适用物种仅支持 CAT/DOG/SMALL/ALL")
        String petSpecies,
        @NotBlank(message = "适用年龄段不能为空")
        @Pattern(regexp = "JUNIOR|ADULT|SENIOR|ALL", message = "年龄段仅支持 JUNIOR/ADULT/SENIOR/ALL")
        String ageStage,
        String weightRange,
        BigDecimal costPrice,
        Integer supportSubscribe,
        Integer isPrescription,
        String detail,
        @Valid List<@NotNull(message = "商品规格不能包含空项") SkuRequest> skus,
        @Valid List<@NotNull(message = "商品图片不能包含空项") ImageRequest> images
)
{
}
