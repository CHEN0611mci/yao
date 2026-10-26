package com.ruoyi.mall.service;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.common.AuthException;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MallRateLimiter;
import com.ruoyi.mall.common.MemberTokenService;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.domain.PetMember;
import com.ruoyi.mall.dto.LoginResponse;
import com.ruoyi.mall.dto.MemberLoginRequest;
import com.ruoyi.mall.dto.MemberRegisterRequest;
import com.ruoyi.mall.dto.MemberUpdateRequest;
import com.ruoyi.mall.dto.PasswordChangeRequest;
import com.ruoyi.mall.mapper.PetMemberMapper;

/**
 * 会员账号服务：注册、登录、资料与后台会员管理。
 *
 * @author ruoyi
 */
@Service
public class MemberService
{
    @Autowired
    private PetMemberMapper memberMapper;

    @Autowired
    private MemberTokenService memberTokenService;

    @Autowired
    private MallRateLimiter rateLimiter;
    @Autowired private MemberWriteLock memberLock;

    @Transactional(rollbackFor = Exception.class)
    public LoginResponse register(MemberRegisterRequest request)
    {
        String username = request.username().trim();
        if (memberMapper.selectByUsername(username) != null)
        {
            throw new BizException(ErrorCode.PET_1002, "用户名已存在");
        }
        String phone = StringUtils.isEmpty(request.phone()) ? null : request.phone().trim();
        if (phone != null && memberMapper.selectByPhone(phone) != null)
        {
            throw new BizException(ErrorCode.PET_1002, "手机号已被注册");
        }

        PetMember member = new PetMember();
        member.setUsername(username);
        member.setPassword(SecurityUtils.encryptPassword(request.password()));
        member.setNickname(request.nickname().trim());
        member.setPhone(phone);
        member.setStatus(0);
        member.setDelFlag("0");
        memberMapper.insert(member);

        String token = memberTokenService.createToken(member);
        return new LoginResponse(token, sanitize(member));
    }

    @Transactional(rollbackFor = Exception.class)
    public LoginResponse login(MemberLoginRequest request)
    {
        String username = request.username().trim();
        rateLimiter.check("member-login", username, 10, 60);

        PetMember member = memberMapper.selectByUsername(username);
        if (member != null) member = memberLock.acquire(member.getId());
        if (member == null || !SecurityUtils.matchesPassword(request.password(), member.getPassword()))
        {
            throw new BizException(ErrorCode.PET_2002);
        }
        if (member.getStatus() != null && member.getStatus() == 1)
        {
            throw new BizException(ErrorCode.PET_2004);
        }
        String token = memberTokenService.createToken(member);
        return new LoginResponse(token, sanitize(member));
    }

    public PetMember me(Long memberId)
    {
        PetMember member = memberMapper.selectById(memberId);
        if (member == null)
        {
            throw new AuthException("会员不存在或已注销");
        }
        if (member.getStatus() != null && member.getStatus() == 1)
        {
            throw new BizException(ErrorCode.PET_2004);
        }
        return sanitize(member);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetMember updateProfile(Long memberId, MemberUpdateRequest request)
    {
        PetMember member = requireMember(memberId);
        member.setNickname(request.nickname().trim());
        member.setAvatar(StringUtils.isEmpty(request.avatar()) ? null : request.avatar().trim());
        memberMapper.updateProfile(member);
        return sanitize(memberMapper.selectById(memberId));
    }

    public PageResult<PetMember> adminList(String keyword, Integer status, int pageNum, int pageSize)
    {
        PageHelper.startPage(pageNum, pageSize);
        List<PetMember> list = memberMapper.selectList(StringUtils.trim(keyword), status);
        PageInfo<PetMember> pageInfo = new PageInfo<>(list);
        for (PetMember member : pageInfo.getList())
        {
            sanitize(member);
        }
        return PageResult.of(pageInfo);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetMember updateStatus(Long memberId, Integer status)
    {
        PetMember member = requireMember(memberId);
        memberMapper.updateStatus(memberId, status);
        if (status != null && status == 1)
        {
            memberTokenService.invalidateByMemberId(memberId);
        }
        member.setStatus(status);
        return sanitize(member);
    }

    public PetMember requireMember(Long memberId)
    {
        PetMember member = memberMapper.selectById(memberId);
        if (member == null)
        {
            throw new ForbiddenException("会员不存在");
        }
        return member;
    }

    @Transactional(rollbackFor = Exception.class)
    public void changePassword(Long memberId, PasswordChangeRequest request)
    {
        rateLimiter.check("member-password", String.valueOf(memberId), 5, 600);
        PetMember member = memberLock.acquire(memberId);
        if (!SecurityUtils.matchesPassword(request.oldPassword(), member.getPassword()))
            throw new BizException(ErrorCode.PET_2002, "原密码不正确");
        if (request.oldPassword().equals(request.newPassword()))
            throw new BizException(ErrorCode.PET_1001, "新密码不能与原密码相同");
        if (memberMapper.changePassword(memberId, member.getPassword(),
                SecurityUtils.encryptPassword(request.newPassword())) != 1)
            throw new BizException(ErrorCode.PET_1001, "密码已变化，请重新登录");
        memberTokenService.invalidateByMemberId(memberId);
    }

    @Transactional(rollbackFor=Exception.class)
    public void changePhone(Long memberId, com.ruoyi.mall.dto.PhoneChangeRequest request)
    {
        rateLimiter.check("member-phone",String.valueOf(memberId),5,600);
        PetMember member = memberLock.acquire(memberId);
        if(!SecurityUtils.matchesPassword(request.password(),member.getPassword()))
            throw new BizException(ErrorCode.PET_2002,"密码不正确");
        if(request.phone().equals(member.getPhone())) throw new BizException(ErrorCode.PET_1001,"联系手机号未变化");
        PetMember existing = memberMapper.selectByPhone(request.phone());
        if(existing != null && !memberId.equals(existing.getId())) throw new BizException(ErrorCode.PET_1002,"手机号已被使用");
        memberMapper.changePhone(memberId,request.phone());
        memberTokenService.invalidateByMemberId(memberId);
    }

    private PetMember sanitize(PetMember member)
    {
        if (member == null)
        {
            return null;
        }
        member.setPassword(null);
        member.setPhone(MemberTokenService.maskPhone(member.getPhone()));
        return member;
    }
}
