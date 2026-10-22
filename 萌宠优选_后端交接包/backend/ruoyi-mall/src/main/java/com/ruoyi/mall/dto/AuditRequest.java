package com.ruoyi.mall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 商品审核请求：1驳回，2通过。
 *
 * @author ruoyi
 */
public record AuditRequest(
        @NotNull(message = "审核结论不能为空") @Min(1) @Max(2) Integer auditStatus,
        @Size(max = 500, message = "审核意见最多500个字符") String remark
)
{
}
