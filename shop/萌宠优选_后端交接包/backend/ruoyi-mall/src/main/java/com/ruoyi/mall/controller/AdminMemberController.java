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
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetMember;
import com.ruoyi.mall.dto.StatusRequest;
import com.ruoyi.mall.service.MemberService;

/**
 * 后台会员管理接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/members")
public class AdminMemberController
{
    @Autowired
    private MemberService memberService;

    @PreAuthorize("@ss.hasPermi('mall:member:list')")
    @GetMapping
    public Result<PageResult<PetMember>> list(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "pageNum", defaultValue = "1") int pageNum,
            @RequestParam(value = "pageSize", defaultValue = "10") int pageSize)
    {
        int safePageNum = Math.max(pageNum, 1);
        int safePageSize = Math.min(Math.max(pageSize, 1), 100);
        return Result.success(memberService.adminList(keyword, status, safePageNum, safePageSize));
    }

    @PreAuthorize("@ss.hasPermi('mall:member:status')")
    @Log(title = "商城-会员管理", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}/status")
    public Result<PetMember> updateStatus(@PathVariable("id") Long id,
            @Valid @RequestBody StatusRequest request)
    {
        return Result.success(memberService.updateStatus(id, request.status()));
    }
}
