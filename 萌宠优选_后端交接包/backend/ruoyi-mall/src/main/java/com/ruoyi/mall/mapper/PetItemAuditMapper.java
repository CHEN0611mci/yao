package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetItemAudit;

/**
 * 商品审核留痕 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetItemAuditMapper
{
    List<PetItemAudit> selectByItemId(@Param("itemId") Long itemId);

    int insert(PetItemAudit audit);
}
