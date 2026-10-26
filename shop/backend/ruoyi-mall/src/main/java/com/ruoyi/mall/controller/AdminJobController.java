package com.ruoyi.mall.controller;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.service.OrderService;

/**
 * 后台补偿任务接口：用于定时任务或手工兜底触发。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/jobs")
public class AdminJobController
{
    @Autowired
    private OrderService orderService;

    @PreAuthorize("@ss.hasPermi('mall:job:trigger')")
    @Log(title = "商城-补偿任务", businessType = BusinessType.UPDATE)
    @PostMapping("/close-timeout-orders")
    public Result<Map<String, Object>> closeTimeoutOrders()
    {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("closed", orderService.closeTimeoutOrders());
        return Result.success("超时订单已关闭", data);
    }

    @PreAuthorize("@ss.hasPermi('mall:job:trigger')")
    @Log(title = "商城-补偿任务", businessType = BusinessType.UPDATE)
    @PostMapping("/auto-confirm-orders")
    public Result<Map<String, Object>> autoConfirmOrders()
    {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("confirmed", orderService.autoConfirmOrders());
        return Result.success("超时订单已自动确认收货", data);
    }
}
