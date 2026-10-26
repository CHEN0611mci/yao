package com.ruoyi.mall.state;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;

/**
 * 订单状态机：只有矩阵内的迁移被允许。
 *
 * @author ruoyi
 */
@Component
public class OrderStateMachine
{
    private static final Map<Integer, Set<Integer>> TRANSITIONS;

    static
    {
        Map<Integer, Set<Integer>> map = new HashMap<>();
        map.put(OrderStatus.PENDING_PAYMENT.getCode(), setOf(
                OrderStatus.PENDING_SHIPMENT.getCode(),
                OrderStatus.CANCELLED.getCode(),
                OrderStatus.CLOSED.getCode()));
        map.put(OrderStatus.PENDING_AUDIT.getCode(), setOf(
                OrderStatus.PENDING_SHIPMENT.getCode(),
                OrderStatus.CANCELLED.getCode()));
        map.put(OrderStatus.PENDING_SHIPMENT.getCode(), setOf(
                OrderStatus.PENDING_RECEIPT.getCode()));
        map.put(OrderStatus.PENDING_RECEIPT.getCode(), setOf(
                OrderStatus.COMPLETED.getCode(),
                OrderStatus.AFTER_SALE.getCode()));
        map.put(OrderStatus.AFTER_SALE.getCode(), setOf(
                OrderStatus.COMPLETED.getCode(),
                OrderStatus.REFUNDED.getCode()));
        map.put(OrderStatus.COMPLETED.getCode(), Collections.emptySet());
        map.put(OrderStatus.CANCELLED.getCode(), Collections.emptySet());
        map.put(OrderStatus.CLOSED.getCode(), Collections.emptySet());
        map.put(OrderStatus.REFUNDED.getCode(), Collections.emptySet());
        TRANSITIONS = Collections.unmodifiableMap(map);
    }

    private static Set<Integer> setOf(Integer... values)
    {
        return Collections.unmodifiableSet(new HashSet<>(Arrays.asList(values)));
    }

    public boolean canTransition(int from, int to)
    {
        return TRANSITIONS.getOrDefault(from, Collections.emptySet()).contains(to);
    }

    public void assertTransition(int from, int to)
    {
        if (!canTransition(from, to))
        {
            throw new BizException(ErrorCode.PET_3002,
                    "订单状态不允许从[" + OrderStatus.labelOf(from) + "]变更为[" + OrderStatus.labelOf(to) + "]");
        }
    }

    public void assertCurrent(Integer actual, OrderStatus expected)
    {
        if (actual == null || actual != expected.getCode())
        {
            throw new BizException(ErrorCode.PET_3002,
                    "当前订单状态为[" + OrderStatus.labelOf(actual) + "]，要求[" + expected.getLabel() + "]");
        }
    }
}
