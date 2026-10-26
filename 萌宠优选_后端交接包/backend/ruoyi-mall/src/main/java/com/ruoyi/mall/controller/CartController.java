package com.ruoyi.mall.controller;

import java.util.List;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetCartItem;
import com.ruoyi.mall.dto.CartAddRequest;
import com.ruoyi.mall.dto.CartUpdateRequest;
import com.ruoyi.mall.service.CartService;

/**
 * 会员购物车接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/cart")
public class CartController
{
    @Autowired
    private CartService cartService;

    @GetMapping
    public Result<List<PetCartItem>> list()
    {
        return Result.success(cartService.list(MemberContext.require()));
    }

    @PostMapping("/items")
    public Result<PetCartItem> add(@Valid @RequestBody CartAddRequest request)
    {
        return Result.success("已加入购物车", cartService.add(MemberContext.require(), request));
    }

    @PutMapping("/items/{id}")
    public Result<PetCartItem> update(@PathVariable("id") Long id,
            @Valid @RequestBody CartUpdateRequest request)
    {
        return Result.success(cartService.update(MemberContext.require(), id, request));
    }

    @DeleteMapping("/items/{id}")
    public Result<Void> remove(@PathVariable("id") Long id)
    {
        cartService.remove(MemberContext.require(), id);
        return Result.success();
    }
}
