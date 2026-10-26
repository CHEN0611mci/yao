package com.ruoyi.mall.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Conditional SQL transitions make concurrent nodes and manual job triggers idempotent. */
@Component
@ConditionalOnProperty(name = "mall.jobs.enabled", havingValue = "true", matchIfMissing = true)
public class OrderLifecycleJob
{
    private static final Logger log = LoggerFactory.getLogger(OrderLifecycleJob.class);
    @Autowired private OrderService orderService;

    @Scheduled(fixedDelayString = "${mall.jobs.close-delay-ms:30000}", initialDelayString = "${mall.jobs.initial-delay-ms:15000}")
    public void closeExpired()
    {
        try { orderService.closeTimeoutOrders(); }
        catch (Exception e) { log.error("自动关单失败，将在下一轮重试", e); }
    }

    @Scheduled(fixedDelayString = "${mall.jobs.confirm-delay-ms:60000}", initialDelayString = "${mall.jobs.initial-delay-ms:15000}")
    public void confirmDelivered()
    {
        try { orderService.autoConfirmOrders(); }
        catch (Exception e) { log.error("自动收货失败，将在下一轮重试", e); }
    }
}
