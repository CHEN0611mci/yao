package com.ruoyi.mall.dto;

import java.util.List;

/**
 * 宠物适配判定结果。
 *
 * @param level SUITABLE / CAUTION / UNSUITABLE / UNKNOWN
 * @param petId 宠物档案ID
 * @param petName 宠物名
 * @param reasons 原因列表
 * @author ruoyi
 */
public record AdaptResult(String level, Long petId, String petName, List<String> reasons)
{
}
