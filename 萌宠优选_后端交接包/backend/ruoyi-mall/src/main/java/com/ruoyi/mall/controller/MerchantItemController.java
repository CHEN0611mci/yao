package com.ruoyi.mall.controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
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
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.dto.ItemQuery;
import com.ruoyi.mall.dto.ItemSaveRequest;
import com.ruoyi.mall.dto.StatusRequest;
import com.ruoyi.mall.service.ItemService;

/**
 * 商家商品接口：仅能操作本人（merchant_id = 所属部门）商品。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/merchant/items")
public class MerchantItemController
{
    @Autowired
    private ItemService itemService;

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:list')")
    @GetMapping
    public Result<PageResult<PetItem>> list(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "categoryId", required = false) Long categoryId,
            @RequestParam(value = "auditStatus", required = false) Integer auditStatus,
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "pageNum", required = false) Integer pageNum,
            @RequestParam(value = "pageSize", required = false) Integer pageSize)
    {
        ItemQuery query = new ItemQuery(keyword, categoryId, null, null, null, null, null,
                auditStatus, status, null, pageNum, pageSize);
        return Result.success(itemService.merchantList(query, MerchantContext.requireMerchantId()));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:list')")
    @GetMapping("/{id}")
    public Result<PetItem> detail(@PathVariable("id") Long id)
    {
        return Result.success(itemService.merchantDetail(id, MerchantContext.requireMerchantId()));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:add')")
    @Log(title = "商城-商家商品", businessType = BusinessType.INSERT)
    @PostMapping
    public Result<PetItem> create(@Valid @RequestBody ItemSaveRequest request)
    {
        return Result.success("商品已提交审核",
                itemService.create(request, MerchantContext.requireMerchantId(), false));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:edit')")
    @Log(title = "商城-商家商品", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}")
    public Result<PetItem> update(@PathVariable("id") Long id,
            @Valid @RequestBody ItemSaveRequest request)
    {
        return Result.success("商品已更新",
                itemService.update(id, request, MerchantContext.requireMerchantId(), false));
    }

    @PreAuthorize("@ss.hasPermi('mall:merchant:item:status')")
    @Log(title = "商城-商家商品", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable("id") Long id,
            @Valid @RequestBody StatusRequest request)
    {
        itemService.updateStatus(id, request.status(), MerchantContext.requireMerchantId(), false);
        return Result.success();
    }
}
