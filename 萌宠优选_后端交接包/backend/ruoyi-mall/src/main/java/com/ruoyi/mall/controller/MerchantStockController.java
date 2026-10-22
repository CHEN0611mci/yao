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
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MerchantContext;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetStockLog;
import com.ruoyi.mall.dto.StockAdjustRequest;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.service.ItemService;
import com.ruoyi.mall.service.OrderService;
import com.ruoyi.mall.service.StockService;

/**
 * 商家库存接口：仅能查看与调整本人 SKU。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/merchant/stock")
public class MerchantStockController
{
    @Autowired
    private StockService stockService;

    @Autowired
    private ItemService itemService;

    @Autowired
    private OrderService orderService;

    @Autowired
    private PetItemSkuMapper itemSkuMapper;

    /**
     * 库存查看复用「我的商品」列表权限，避免为一期未定义的库存菜单额外配置权限码。
     */
    @PreAuthorize("@ss.hasPermi('mall:merchant:item:list')")
    @GetMapping
    public Result<List<Map<String, Object>>> overview(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "itemId", required = false) Long itemId,
            @RequestParam(value = "lowStock", defaultValue = "false") boolean lowStock,
            @RequestParam(value = "threshold", defaultValue = "10") int threshold)
    {
        Map<String, Object> query = new HashMap<>();
        query.put("keyword", keyword);
        query.put("itemId", itemId);
        query.put("merchantId", MerchantContext.requireMerchantId());
        query.put("lowStock", lowStock);
        query.put("threshold", threshold);
        return Result.success(stockService.overview(query));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:list')")
    @GetMapping("/logs")
    public Result<List<PetStockLog>> logs(
            @RequestParam(value = "skuId", required = false) Long skuId,
            @RequestParam(value = "orderNo", required = false) String orderNo,
            @RequestParam(value = "type", required = false) String type)
    {
        Long merchantId = MerchantContext.requireMerchantId();
        if (skuId != null)
        {
            assertOwnedSku(skuId, merchantId);
        }
        if (orderNo != null && !orderNo.isEmpty())
        {
            // 校验订单中是否包含该商家商品，避免跨商家查看流水
            orderService.merchantDetail(merchantId, orderNo);
        }
        Map<String, Object> query = new HashMap<>();
        query.put("skuId", skuId);
        query.put("orderNo", orderNo);
        query.put("type", type);
        return Result.success(stockService.logs(query));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:edit')")
    @Log(title = "商城-商家库存", businessType = BusinessType.UPDATE)
    @PutMapping("/{skuId}")
    public Result<PetItemSku> adjust(@PathVariable("skuId") Long skuId,
            @Valid @RequestBody StockAdjustRequest request)
    {
        Long merchantId = MerchantContext.requireMerchantId();
        assertOwnedSku(skuId, merchantId);
        return Result.success("库存已调整",
                stockService.adjust(skuId, request.targetStock(), MerchantContext.operator(), request.remark()));
    }

    private void assertOwnedSku(Long skuId, Long merchantId)
    {
        PetItemSku sku = itemSkuMapper.selectById(skuId);
        if (sku == null)
        {
            throw new ForbiddenException("SKU 不存在或不属于当前商家");
        }
        // merchantDetail 会在商品不属于该商家时抛出越权异常
        itemService.merchantDetail(sku.getItemId(), merchantId);
    }
}
