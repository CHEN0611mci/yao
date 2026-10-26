package com.ruoyi.mall.controller;

import java.math.BigDecimal;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberTokenService;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.dto.ItemQuery;
import com.ruoyi.mall.service.ItemService;

/**
 * 前台商品接口：列表检索与详情，允许匿名访问（携带会员 Token 时附加适配结论）。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/items")
public class ItemController
{
    @Autowired
    private ItemService itemService;

    @Autowired
    private MemberTokenService memberTokenService;

    @GetMapping
    public Result<PageResult<PetItem>> list(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "categoryId", required = false) Long categoryId,
            @RequestParam(value = "species", required = false) String species,
            @RequestParam(value = "ageStage", required = false) String ageStage,
            @RequestParam(value = "minPrice", required = false) BigDecimal minPrice,
            @RequestParam(value = "maxPrice", required = false) BigDecimal maxPrice,
            @RequestParam(value = "sort", required = false) String sort,
            @RequestParam(value = "pageNum", required = false) Integer pageNum,
            @RequestParam(value = "pageSize", required = false) Integer pageSize,
            HttpServletRequest request)
    {
        ItemQuery query = new ItemQuery(keyword, categoryId, species, ageStage, minPrice, maxPrice,
                sort, null, null, null, pageNum, pageSize);
        return Result.success(itemService.publicList(query, memberTokenService.optionalMemberId(request)));
    }

    @GetMapping("/{id}")
    public Result<PetItem> detail(@PathVariable("id") Long id, HttpServletRequest request)
    {
        return Result.success(itemService.publicDetail(id, memberTokenService.optionalMemberId(request)));
    }
}
