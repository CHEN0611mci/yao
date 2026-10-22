package com.ruoyi.mall.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.dto.DashboardSummary;
import com.ruoyi.mall.service.DashboardService;

/**
 * 后台首页看板接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/dashboard")
public class AdminDashboardController
{
    @Autowired
    private DashboardService dashboardService;

    @PreAuthorize("@ss.hasPermi('mall:dashboard:view')")
    @GetMapping("/summary")
    public Result<DashboardSummary> summary()
    {
        return Result.success(dashboardService.summary());
    }
}
