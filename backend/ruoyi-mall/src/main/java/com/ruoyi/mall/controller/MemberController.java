package com.ruoyi.mall.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
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
import com.ruoyi.mall.dto.PasswordChangeRequest;
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
    @Autowired private com.ruoyi.system.service.ISysOperLogService operLogService;
    @Autowired private com.ruoyi.mall.common.MallRateLimiter rateLimiter;

    @PostMapping("/feedback")
    public Result<Void> feedback(@Valid @RequestBody com.ruoyi.mall.dto.FeedbackRequest request)
    {
        Long memberId = MemberContext.require();
        rateLimiter.check("feedback", String.valueOf(memberId), 5, 600);
        var log = new com.ruoyi.system.domain.SysOperLog();
        log.setTitle("商城意见反馈"); log.setBusinessType(0); log.setOperatorType(0);
        log.setOperName("member:" + memberId); log.setOperUrl("/api/member/feedback");
        log.setMethod("MemberController.feedback"); log.setRequestMethod("POST");
        log.setOperParam(request.content().trim()); log.setStatus(0); log.setCostTime(0L);
        operLogService.insertOperlog(log);
        return Result.success();
    }
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

    @PutMapping("/password")
    public Result<Void> password(@Valid @RequestBody PasswordChangeRequest request)
    {
        memberService.changePassword(MemberContext.require(), request);
        return Result.success();
    }
    @PutMapping("/phone")
    public Result<Void> phone(@Valid @RequestBody com.ruoyi.mall.dto.PhoneChangeRequest request)
    { memberService.changePhone(MemberContext.require(),request); return Result.success(); }
    @GetMapping("/sessions")
    public Result<java.util.List<MemberTokenService.SessionView>> sessions(HttpServletRequest request)
    { return Result.success(memberTokenService.sessions(MemberContext.require(),MemberTokenService.resolveToken(request))); }
    @DeleteMapping("/sessions/{id}")
    public Result<Boolean> revoke(@PathVariable String id)
    { return Result.success(memberTokenService.revoke(MemberContext.require(),id)); }
    @PostMapping("/sessions/revoke-others")
    public Result<Integer> revokeOthers(HttpServletRequest request)
    { return Result.success(memberTokenService.revokeOthers(MemberContext.require(),MemberTokenService.resolveToken(request))); }
}
