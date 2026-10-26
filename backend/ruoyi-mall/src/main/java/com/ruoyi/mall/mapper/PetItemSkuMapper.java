package com.ruoyi.mall.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetItemSku;

/**
 * 商品 SKU Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetItemSkuMapper
{
    List<PetItemSku> selectByItemId(@Param("itemId") Long itemId, @Param("onlyEnabled") boolean onlyEnabled);

    PetItemSku selectById(@Param("id") Long id);

    Integer selectStock(@Param("id") Long id);

    int deductStock(@Param("id") Long id, @Param("quantity") Integer quantity);

    int increaseStock(@Param("id") Long id, @Param("quantity") Integer quantity);

    int insert(PetItemSku sku);

    int update(PetItemSku sku);

    int deleteByItemId(@Param("itemId") Long itemId);

    int countByItemId(@Param("itemId") Long itemId);

    List<Map<String, Object>> selectStockOverview(Map<String, Object> query);

    List<Map<String, Object>> selectLowStock(@Param("threshold") int threshold, @Param("limit") int limit);
}
