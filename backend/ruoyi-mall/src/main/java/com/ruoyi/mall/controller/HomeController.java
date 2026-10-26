package com.ruoyi.mall.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberTokenService;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetCategory;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.service.CategoryService;
import com.ruoyi.mall.service.ItemService;
import com.ruoyi.mall.service.StorefrontService;

/**
 * 前台首页接口：分类树与推荐商品，均支持匿名访问。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/home")
public class HomeController
{
    @Autowired private StorefrontService storefrontService;

    @GetMapping("/settings")
    public Result<java.util.Map<String, Object>> settings()
    {
        return Result.success(storefrontService.settings());
    }
    @Autowired
    private CategoryService categoryService;

    @Autowired
    private ItemService itemService;

    @Autowired
    private MemberTokenService memberTokenService;

    @GetMapping("/categories")
    public Result<List<PetCategory>> categories()
    {
        return Result.success(categoryService.tree(true));
    }

    @GetMapping("/recommend")
    public Result<List<PetItem>> recommend(@RequestParam(value = "limit", defaultValue = "10") int limit,
            HttpServletRequest request)
    {
        int safeLimit = Math.min(Math.max(limit, 1), 50);
        return Result.success(itemService.recommend(safeLimit, memberTokenService.optionalMemberId(request)));
    }
}
