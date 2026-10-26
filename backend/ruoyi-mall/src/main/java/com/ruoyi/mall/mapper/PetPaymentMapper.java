package com.ruoyi.mall.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetPayment;

/**
 * 支付记录 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetPaymentMapper
{
    int insert(PetPayment payment);

    int bindRequest(@Param("idempotencyKey") String idempotencyKey, @Param("paymentId") Long paymentId);

    PetPayment selectByOrderNo(@Param("orderNo") String orderNo);

    PetPayment selectByIdempotencyKey(@Param("idempotencyKey") String idempotencyKey);
}
