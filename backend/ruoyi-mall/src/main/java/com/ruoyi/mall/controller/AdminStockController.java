package com.ruoyi.mall.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
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
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetStockLog;
import com.ruoyi.mall.dto.StockAdjustRequest;
import com.ruoyi.mall.service.StockService;

/**
 * 后台库存管理接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/stock")
public class AdminStockController
{
    @Autowired
    private StockService stockService;

    @PreAuthorize("@ss.hasPermi('mall:stock:list')")
    @GetMapping
    public Result<List<Map<String, Object>>> overview(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "itemId", required = false) Long itemId,
            @RequestParam(value = "merchantId", required = false) Long merchantId,
            @RequestParam(value = "lowStock", defaultValue = "false") boolean lowStock,
            @RequestParam(value = "threshold", defaultValue = "10") int threshold)
    {
        Map<String, Object> query = new HashMap<>();
        query.put("keyword", keyword);
        query.put("itemId", itemId);
        query.put("merchantId", merchantId);
        query.put("lowStock", lowStock);
        query.put("threshold", threshold);
        return Result.success(stockService.overview(query));
    }

    @PreAuthorize("@ss.hasPermi('mall:stock:list')")
    @GetMapping("/logs")
    public Result<List<PetStockLog>> logs(
            @RequestParam(value = "skuId", required = false) Long skuId,
            @RequestParam(value = "orderNo", required = false) String orderNo,
            @RequestParam(value = "type", required = false) String type)
    {
        Map<String, Object> query = new HashMap<>();
        query.put("skuId", skuId);
        query.put("orderNo", orderNo);
        query.put("type", type);
        return Result.success(stockService.logs(query));
    }

    @PreAuthorize("@ss.hasPermi('mall:stock:adjust')")
    @Log(title = "商城-库存管理", businessType = BusinessType.UPDATE)
    @PutMapping("/{skuId}")
    public Result<PetItemSku> adjust(@PathVariable("skuId") Long skuId,
            @Valid @RequestBody StockAdjustRequest request)
    {
        return Result.success("库存已调整",
                stockService.adjust(skuId, request.targetStock(), MerchantContext.operator(), request.remark()));
    }
}
