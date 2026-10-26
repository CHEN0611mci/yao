package com.ruoyi.mall.controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.mall.common.*;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.dto.NotificationPreference;
import com.ruoyi.mall.service.MemberFeatureService;

@RestController
@RequestMapping("/api/member")
public class MemberFeatureController
{
    @Autowired private MemberFeatureService service;
    @GetMapping("/preferences")
    public Result<NotificationPreference> preference() { return Result.success(service.preference(MemberContext.require())); }
    @PutMapping("/preferences")
    public Result<NotificationPreference> preference(@Valid @RequestBody NotificationPreference value)
    { return Result.success(service.savePreference(MemberContext.require(), value)); }
    @GetMapping("/favorites")
    public Result<PageResult<PetItem>> favorites(@RequestParam(defaultValue="1") int pageNum,@RequestParam(defaultValue="12") int pageSize)
    { return Result.success(service.favorites(MemberContext.require(),pageNum,pageSize)); }
    @GetMapping("/favorites/{itemId}")
    public Result<Boolean> isFavorite(@PathVariable Long itemId) { return Result.success(service.isFavorite(MemberContext.require(),itemId)); }
    @PutMapping("/favorites/{itemId}")
    public Result<Void> addFavorite(@PathVariable Long itemId) { service.addFavorite(MemberContext.require(),itemId);return Result.success(); }
    @DeleteMapping("/favorites/{itemId}")
    public Result<Void> removeFavorite(@PathVariable Long itemId) { service.removeFavorite(MemberContext.require(),itemId);return Result.success(); }
}
