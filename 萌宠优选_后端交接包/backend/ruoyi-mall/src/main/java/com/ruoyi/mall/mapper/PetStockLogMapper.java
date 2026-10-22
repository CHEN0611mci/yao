package com.ruoyi.mall.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetStockLog;

/**
 * 库存流水 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetStockLogMapper
{
    int insert(PetStockLog log);

    int countBySkuOrderType(@Param("skuId") Long skuId, @Param("orderNo") String orderNo,
            @Param("type") String type);

    List<PetStockLog> selectList(Map<String, Object> query);
}
