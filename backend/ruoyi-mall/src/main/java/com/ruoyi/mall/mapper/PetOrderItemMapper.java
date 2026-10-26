package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetOrderItem;

/**
 * 订单明细 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetOrderItemMapper
{
    int batchInsert(@Param("items") List<PetOrderItem> items);

    List<PetOrderItem> selectByOrderId(@Param("orderId") Long orderId);

    List<PetOrderItem> selectByOrderIds(@Param("orderIds") List<Long> orderIds);
}
