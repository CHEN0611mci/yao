package com.ruoyi.mall.controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.mall.common.MerchantContext;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetOrder;
import com.ruoyi.mall.dto.ShipRequest;
import com.ruoyi.mall.dto.ShipResponse;
import com.ruoyi.mall.service.OrderService;

/**
 * 商家订单接口：仅可见含本人商品的订单。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/merchant/orders")
public class MerchantOrderController
{
    @Autowired
    private OrderService orderService;

    @PreAuthorize("@ss.hasPermi('mall:merchant:order:list')")
    @GetMapping
    public Result<PageResult<PetOrder>> list(
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "orderNo", required = false) String orderNo,
            @RequestParam(value = "pageNum", defaultValue = "1") int pageNum,
            @RequestParam(value = "pageSize", defaultValue = "10") int pageSize)
    {
        int safePageNum = Math.max(pageNum, 1);
        int safePageSize = Math.min(Math.max(pageSize, 1), 100);
        return Result.success(orderService.merchantList(MerchantContext.requireMerchantId(), status,
                orderNo, safePageNum, safePageSize));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:order:list')")
    @GetMapping("/{orderNo}")
    public Result<PetOrder> detail(@PathVariable("orderNo") String orderNo)
    {
        return Result.success(orderService.merchantDetail(MerchantContext.requireMerchantId(), orderNo));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:order:ship')")
    @Log(title = "商城-商家订单", businessType = BusinessType.UPDATE)
    @PutMapping("/{orderNo}/ship")
    public Result<ShipResponse> ship(@PathVariable("orderNo") String orderNo,
            @Valid @RequestBody ShipRequest request)
    {
        return Result.success("发货成功",
                orderService.ship(MerchantContext.requireMerchantId(), orderNo, request));
    }
}
