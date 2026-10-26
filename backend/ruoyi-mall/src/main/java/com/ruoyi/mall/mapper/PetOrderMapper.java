package com.ruoyi.mall.mapper;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetOrder;

/**
 * 订单 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetOrderMapper
{
    PetOrder selectByOrderNo(@Param("orderNo") String orderNo);

    PetOrder selectByOrderNoAndMember(@Param("orderNo") String orderNo, @Param("memberId") Long memberId);

    PetOrder selectByClientToken(@Param("memberId") Long memberId, @Param("clientToken") String clientToken);

    int insert(PetOrder order);

    List<PetOrder> selectMemberOrders(@Param("memberId") Long memberId, @Param("status") Integer status,
            @Param("keyword") String keyword);

    int changeAddress(@Param("orderNo") String orderNo, @Param("memberId") Long memberId,
            @Param("snapshot") String snapshot);

    List<PetOrder> selectAdminOrders(Map<String, Object> query);

    List<PetOrder> selectMerchantOrders(Map<String, Object> query);

    int updateToPaid(@Param("orderNo") String orderNo);

    int cancel(@Param("orderNo") String orderNo, @Param("memberId") Long memberId,
            @Param("reason") String reason);

    int confirm(@Param("orderNo") String orderNo, @Param("memberId") Long memberId);

    int ship(@Param("orderNo") String orderNo, @Param("merchantId") Long merchantId);

    /**
     * 发货并写入物流信息（快照 JSON 内追加 logistics 节点）。
     */
    int updateShipInfo(@Param("orderNo") String orderNo, @Param("merchantId") Long merchantId,
            @Param("receiverSnapshot") String receiverSnapshot);

    int close(@Param("orderNo") String orderNo, @Param("reason") String reason);

    List<PetOrder> selectTimeoutOrders(@Param("limit") int limit);

    List<PetOrder> selectAutoConfirmOrders(@Param("days") int days, @Param("limit") int limit);

    long countTodayOrders();

    BigDecimal sumTodaySales();

    long countPendingShipment();
}
