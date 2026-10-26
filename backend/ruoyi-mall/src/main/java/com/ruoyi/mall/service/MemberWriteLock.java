package com.ruoyi.mall.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.mall.common.AuthException;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.domain.PetMember;
import com.ruoyi.mall.mapper.PetMemberMapper;

/** Serializes a member's bounded collection writes inside the caller's transaction. */
@Component
public class MemberWriteLock
{
    @Autowired private PetMemberMapper mapper;
    public PetMember acquire(Long memberId)
    {
        PetMember member = mapper.selectForUpdate(memberId);
        if (member == null) throw new AuthException();
        if (Integer.valueOf(1).equals(member.getStatus())) throw new BizException(ErrorCode.PET_2004);
        return member;
    }
}
