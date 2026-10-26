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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetMemberPet;
import com.ruoyi.mall.dto.PetProfileRequest;
import com.ruoyi.mall.service.PetProfileService;

/**
 * 会员宠物档案接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/member/pets")
public class PetProfileController
{
    @Autowired
    private PetProfileService petProfileService;

    @GetMapping
    public Result<List<PetMemberPet>> list(
            @RequestParam(value = "includeArchived", defaultValue = "false") boolean includeArchived)
    {
        return Result.success(petProfileService.list(MemberContext.require(), includeArchived));
    }

    @GetMapping("/{id}")
    public Result<PetMemberPet> detail(@PathVariable("id") Long id)
    {
        return Result.success(petProfileService.getOwned(MemberContext.require(), id));
    }

    @PostMapping
    public Result<PetMemberPet> create(@Valid @RequestBody PetProfileRequest request)
    {
        return Result.success("档案已创建", petProfileService.create(MemberContext.require(), request));
    }

    @PutMapping("/{id}")
    public Result<PetMemberPet> update(@PathVariable("id") Long id,
            @Valid @RequestBody PetProfileRequest request)
    {
        return Result.success(petProfileService.update(MemberContext.require(), id, request));
    }

    @DeleteMapping("/{id}")
    public Result<Void> archive(@PathVariable("id") Long id)
    {
        petProfileService.archive(MemberContext.require(), id);
        return Result.success("档案已归档", null);
    }
}
