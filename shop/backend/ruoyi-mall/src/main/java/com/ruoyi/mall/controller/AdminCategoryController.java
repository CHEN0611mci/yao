package com.ruoyi.mall.controller;

import java.util.List;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetCategory;
import com.ruoyi.mall.dto.CategoryRequest;
import com.ruoyi.mall.service.CategoryService;

/**
 * 后台两级类目管理接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/categories")
public class AdminCategoryController
{
    @Autowired
    private CategoryService categoryService;

    @PreAuthorize("@ss.hasPermi('mall:category:list')")
    @GetMapping
    public Result<List<PetCategory>> list()
    {
        return Result.success(categoryService.tree(false));
    }

    @PreAuthorize("@ss.hasPermi('mall:category:list')")
    @GetMapping("/{id}")
    public Result<PetCategory> detail(@PathVariable("id") Long id)
    {
        return Result.success(categoryService.get(id));
    }

    @PreAuthorize("@ss.hasPermi('mall:category:add')")
    @Log(title = "商城-类目管理", businessType = BusinessType.INSERT)
    @PostMapping
    public Result<PetCategory> create(@Valid @RequestBody CategoryRequest request)
    {
        return Result.success("类目已创建", categoryService.create(request));
    }

    @PreAuthorize("@ss.hasPermi('mall:category:edit')")
    @Log(title = "商城-类目管理", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}")
    public Result<PetCategory> update(@PathVariable("id") Long id,
            @Valid @RequestBody CategoryRequest request)
    {
        return Result.success("类目已更新", categoryService.update(id, request));
    }

    @PreAuthorize("@ss.hasPermi('mall:category:remove')")
    @Log(title = "商城-类目管理", businessType = BusinessType.DELETE)
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable("id") Long id)
    {
        categoryService.delete(id);
        return Result.success();
    }
}
