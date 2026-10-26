package com.ruoyi.mall.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;

/**
 * 宠物档案新增/编辑请求。
 *
 * @author ruoyi
 */
public record PetProfileRequest(
        @NotBlank(message = "宠物名不能为空")
        @Size(max = 30, message = "宠物名最多30个字符")
        String name,

        @NotBlank(message = "宠物物种不能为空")
        @Pattern(regexp = "CAT|DOG|SMALL", message = "物种仅支持 CAT/DOG/SMALL")
        String species,

        @Size(max = 50, message = "品种最多50个字符")
        String breed,

        @DateTimeFormat(pattern = "yyyy-MM-dd")
        LocalDate birthday,

        @DecimalMin(value = "0.1", message = "体重不能小于0.1kg")
        @DecimalMax(value = "100.0", message = "体重不能大于100kg")
        BigDecimal weight,

        Integer sterilized,

        @Size(max = 200, message = "过敏说明最多200个字符")
        String allergyNote,

        Integer status
)
{
}
