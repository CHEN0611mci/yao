package com.ruoyi.mall.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.MemberTokenService;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetMember;
import com.ruoyi.mall.dto.LoginResponse;
import com.ruoyi.mall.dto.MemberLoginRequest;
import com.ruoyi.mall.dto.MemberRegisterRequest;
import com.ruoyi.mall.dto.MemberUpdateRequest;
import com.ruoyi.mall.service.MemberService;

/**
 * 会员账号接口：注册、登录、登出与个人资料。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/member")
public class MemberController
{
    @Autowired
    private MemberService memberService;

    @Autowired
    private MemberTokenService memberTokenService;

    @PostMapping("/register")
    public Result<LoginResponse> register(@Valid @RequestBody MemberRegisterRequest request)
    {
        return Result.success("注册成功", memberService.register(request));
    }

    @PostMapping("/login")
    public Result<LoginResponse> login(@Valid @RequestBody MemberLoginRequest request)
    {
        return Result.success("登录成功", memberService.login(request));
    }

    @PostMapping("/logout")
    public Result<Void> logout(HttpServletRequest request)
    {
        memberTokenService.logout(request);
        return Result.success();
    }

    @GetMapping("/me")
    public Result<PetMember> me()
    {
        return Result.success(memberService.me(MemberContext.require()));
    }

    @PutMapping("/me")
    public Result<PetMember> updateProfile(@Valid @RequestBody MemberUpdateRequest request)
    {
        return Result.success(memberService.updateProfile(MemberContext.require(), request));
    }
}
