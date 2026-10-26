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
import com.ruoyi.mall.domain.PetAddress;
import com.ruoyi.mall.dto.AddressRequest;
import com.ruoyi.mall.service.AddressService;

/**
 * 会员收货地址接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/member/addresses")
public class AddressController
{
    @Autowired
    private AddressService addressService;

    @GetMapping
    public Result<List<PetAddress>> list()
    {
        return Result.success(addressService.list(MemberContext.require()));
    }

    @GetMapping("/{id}")
    public Result<PetAddress> detail(@PathVariable("id") Long id)
    {
        return Result.success(addressService.getOwned(MemberContext.require(), id));
    }

    @PostMapping
    public Result<PetAddress> create(@Valid @RequestBody AddressRequest request)
    {
        return Result.success("地址已保存", addressService.create(MemberContext.require(), request));
    }

    @PutMapping("/{id}")
    public Result<PetAddress> update(@PathVariable("id") Long id,
            @Valid @RequestBody AddressRequest request)
    {
        return Result.success(addressService.update(MemberContext.require(), id, request));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable("id") Long id)
    {
        addressService.delete(MemberContext.require(), id);
        return Result.success();
    }

    @PutMapping("/{id}/default")
    public Result<PetAddress> setDefault(@PathVariable("id") Long id)
    {
        return Result.success(addressService.setDefault(MemberContext.require(), id));
    }
}
