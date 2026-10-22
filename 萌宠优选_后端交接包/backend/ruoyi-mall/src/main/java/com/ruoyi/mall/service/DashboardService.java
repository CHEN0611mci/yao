package com.ruoyi.mall.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.mall.dto.DashboardSummary;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.mapper.PetMemberMapper;
import com.ruoyi.mall.mapper.PetOrderMapper;

/**
 * 后台经营概览服务。
 *
 * @author ruoyi
 */
@Service
public class DashboardService
{
    @Autowired
    private PetOrderMapper orderMapper;

    @Autowired
    private PetItemSkuMapper skuMapper;

    @Autowired
    private PetMemberMapper memberMapper;

    public DashboardSummary summary()
    {
        long lowStock = skuMapper.selectLowStock(10, 1000).size();
        return new DashboardSummary(orderMapper.countTodayOrders(), orderMapper.sumTodaySales(),
                orderMapper.countPendingShipment(), lowStock, memberMapper.countAll());
    }
}
