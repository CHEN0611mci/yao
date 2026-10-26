package com.ruoyi.mall.dto;

import java.math.BigDecimal;

/**
 * 后台概览。
 *
 * @author ruoyi
 */
public record DashboardSummary(long todayOrders, BigDecimal todaySales, long pendingShipment,
        long lowStockSku, long totalMembers)
{
}
