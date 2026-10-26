package com.ruoyi.mall.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetItem;

/**
 * 商品 SPU Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetItemMapper
{
    List<PetItem> selectPublicList(Map<String, Object> query);

    List<PetItem> selectAdminList(Map<String, Object> query);

    PetItem selectById(@Param("id") Long id);

    PetItem selectSellableById(@Param("id") Long id);

    List<PetItem> selectRecommend(@Param("limit") int limit);

    int insert(PetItem item);

    int update(PetItem item);

    int updateStatus(@Param("id") Long id, @Param("status") Integer status);

    int updateAudit(@Param("id") Long id, @Param("auditStatus") Integer auditStatus);

    int incrementSales(@Param("id") Long id, @Param("quantity") Integer quantity);

    int countByCategory(@Param("categoryId") Long categoryId);
}
