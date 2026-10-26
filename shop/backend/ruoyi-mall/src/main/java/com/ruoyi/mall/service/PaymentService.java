package com.ruoyi.mall.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.domain.PetOrder;
import com.ruoyi.mall.domain.PetPayment;
import com.ruoyi.mall.dto.MockPayRequest;
import com.ruoyi.mall.dto.PayCallbackRequest;
import com.ruoyi.mall.dto.PaymentResponse;
import com.ruoyi.mall.mapper.PetOrderMapper;
import com.ruoyi.mall.mapper.PetPaymentMapper;

/**
 * 支付服务：沙箱三分支、回调验金额与幂等落库。
 *
 * @author ruoyi
 */
@Service
public class PaymentService
{
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    @Autowired
    private PetOrderMapper orderMapper;

    @Autowired
    private PetPaymentMapper paymentMapper;

    @Autowired
    private MessageService messageService;

    @Transactional(rollbackFor = Exception.class)
    public PaymentResponse mockPay(Long memberId, MockPayRequest request, String idempotencyKey)
    {
        PetOrder order = orderMapper.selectByOrderNoAndMember(request.orderNo(), memberId);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        String key = StringUtils.isEmpty(idempotencyKey)
                ? "MOCK-" + order.getOrderNo() + "-" + request.result()
                : idempotencyKey.trim();
        PetPayment existing = paymentMapper.selectByIdempotencyKey(key);
        if (existing != null)
        {
            if (!existing.getOrderNo().equals(order.getOrderNo()))
            {
                throw new BizException(ErrorCode.PET_1002, "幂等键已被其他订单使用");
            }
            return response(existing, true);
        }
        return settle(order, order.getPayAmount(), request.channel(),
                request.result().toUpperCase(), key);
    }

    @Transactional(rollbackFor = Exception.class)
    public PaymentResponse callback(PayCallbackRequest request, String idempotencyKey)
    {
        if (StringUtils.isEmpty(idempotencyKey))
        {
            throw new BizException(ErrorCode.PET_1001, "Idempotency-Key不能为空");
        }
        String key = idempotencyKey.trim();
        PetPayment existing = paymentMapper.selectByIdempotencyKey(key);
        if (existing != null)
        {
            return response(existing, true);
        }
        PetOrder order = orderMapper.selectByOrderNo(request.orderNo());
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        if (request.amount().compareTo(order.getPayAmount()) != 0)
        {
            throw new BizException(ErrorCode.PET_4002,
                    "回调金额" + request.amount() + "与订单应付" + order.getPayAmount() + "不一致");
        }
        return settle(order, request.amount(), request.channel(),
                request.result().toUpperCase(), key);
    }

    public PaymentResponse query(Long memberId, String orderNo)
    {
        PetOrder order = orderMapper.selectByOrderNoAndMember(orderNo, memberId);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        PetPayment payment = paymentMapper.selectByOrderNo(orderNo);
        if (payment == null)
        {
            return new PaymentResponse(null, "UNPAID", order.getStatus(), false);
        }
        return response(payment, false);
    }

    private PaymentResponse settle(PetOrder order, BigDecimal amount, String channel,
            String result, String idempotencyKey)
    {
        boolean success = "SUCCESS".equals(result);
        Integer orderStatus = order.getStatus();
        boolean duplicated = false;
        if (success)
        {
            if (order.getStatus() != null && order.getStatus() == 0)
            {
                int rows = orderMapper.updateToPaid(order.getOrderNo());
                if (rows > 0)
                {
                    orderStatus = 2;
                }
                else
                {
                    PetOrder latest = orderMapper.selectByOrderNo(order.getOrderNo());
                    if (latest != null && latest.getStatus() != null
                            && (latest.getStatus() == 2 || latest.getStatus() == 3
                                    || latest.getStatus() == 4))
                    {
                        orderStatus = latest.getStatus();
                        duplicated = true;
                    }
                    else
                    {
                        throw new BizException(ErrorCode.PET_3002, "订单当前状态不可支付");
                    }
                }
            }
            else if (order.getStatus() != null
                    && (order.getStatus() == 2 || order.getStatus() == 3 || order.getStatus() == 4))
            {
                duplicated = true;
            }
            else
            {
                throw new BizException(ErrorCode.PET_3002, "订单当前状态不可支付");
            }
        }

        PetPayment payment = new PetPayment();
        payment.setPaymentNo(nextPaymentNo());
        payment.setOrderNo(order.getOrderNo());
        payment.setAmount(amount);
        payment.setChannel(channel);
        payment.setStatus(success ? "SUCCESS" : ("TIMEOUT".equals(result) ? "TIMEOUT" : "FAILED"));
        payment.setIdempotencyKey(idempotencyKey);
        paymentMapper.insert(payment);
        if (success && !duplicated)
        {
            messageService.notify(order.getMemberId(), "ORDER", "支付成功",
                    "订单" + order.getOrderNo() + "已支付成功，我们会尽快为您发货。",
                    "/pages/order/detail?orderNo=" + order.getOrderNo());
        }
        return new PaymentResponse(payment.getPaymentNo(), payment.getStatus(), orderStatus, duplicated);
    }

    private PaymentResponse response(PetPayment payment, boolean duplicated)
    {
        PetOrder order = orderMapper.selectByOrderNo(payment.getOrderNo());
        return new PaymentResponse(payment.getPaymentNo(), payment.getStatus(),
                order == null ? null : order.getStatus(), duplicated);
    }

    private String nextPaymentNo()
    {
        return "PAY" + LocalDateTime.now().format(TIME_FORMAT)
                + String.format("%06d", ThreadLocalRandom.current().nextInt(1_000_000))
                + UUID.randomUUID().toString().substring(0, 4);
    }
}
