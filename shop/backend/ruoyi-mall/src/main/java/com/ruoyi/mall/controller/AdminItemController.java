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
import com.ruoyi.mall.dto.AuditRequest;
import com.ruoyi.mall.dto.AuditResponse;
import com.ruoyi.mall.dto.ItemQuery;
import com.ruoyi.mall.dto.ItemSaveRequest;
import com.ruoyi.mall.dto.StatusRequest;
import com.ruoyi.mall.service.ItemService;

/**
 * 后台商品治理接口：列表、创建、上下架与审核。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/items")
public class AdminItemController
{
    @Autowired
    private ItemService itemService;

    /**
     * 商品列表同时服务于「商品管理」与「商品审核」两个菜单：
     * 审核员仅持有 mall:item:audit，也需要按 auditStatus 查询待审队列。
     */
    @PreAuthorize("@ss.hasAnyPermi('mall:item:list,mall:item:audit')")
    @GetMapping
    public Result<PageResult<PetItem>> list(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "categoryId", required = false) Long categoryId,
            @RequestParam(value = "species", required = false) String species,
            @RequestParam(value = "auditStatus", required = false) Integer auditStatus,
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "merchantId", required = false) Long merchantId,
            @RequestParam(value = "pageNum", required = false) Integer pageNum,
            @RequestParam(value = "pageSize", required = false) Integer pageSize)
    {
        ItemQuery query = new ItemQuery(keyword, categoryId, species, null, null, null, null,
                auditStatus, status, merchantId, pageNum, pageSize);
        return Result.success(itemService.adminList(query));
    }

    @PreAuthorize("@ss.hasAnyPermi('mall:item:list,mall:item:audit')")
    @GetMapping("/{id}")
    public Result<PetItem> detail(@PathVariable("id") Long id)
    {
        return Result.success(itemService.adminDetail(id));
    }

    @PreAuthorize("@ss.hasPermi('mall:item:add')")
    @Log(title = "商城-商品管理", businessType = BusinessType.INSERT)
    @PostMapping
    public Result<PetItem> create(@Valid @RequestBody ItemSaveRequest request)
    {
        return Result.success("商品已创建", itemService.create(request, request.merchantId(), true));
    }

    @PreAuthorize("@ss.hasPermi('mall:item:edit')")
    @Log(title = "商城-商品管理", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}")
    public Result<PetItem> update(@PathVariable("id") Long id,
            @Valid @RequestBody ItemSaveRequest request)
    {
        return Result.success("商品已更新", itemService.update(id, request, request.merchantId(), true));
    }

    @PreAuthorize("@ss.hasPermi('mall:item:status')")
    @Log(title = "商城-商品管理", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable("id") Long id,
            @Valid @RequestBody StatusRequest request)
    {
        itemService.updateStatus(id, request.status(), null, true);
        return Result.success();
    }

    @PreAuthorize("@ss.hasPermi('mall:item:audit')")
    @Log(title = "商城-商品审核", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}/audit")
    public Result<AuditResponse> audit(@PathVariable("id") Long id,
            @Valid @RequestBody AuditRequest request)
    {
        return Result.success("审核完成",
                itemService.audit(id, request, MerchantContext.operator()));
    }
}
