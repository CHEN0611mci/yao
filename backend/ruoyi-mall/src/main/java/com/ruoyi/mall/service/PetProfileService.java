package com.ruoyi.mall.service;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.domain.PetMemberPet;
import com.ruoyi.mall.dto.PetProfileRequest;
import com.ruoyi.mall.mapper.PetMemberPetMapper;

/**
 * 宠物档案服务。
 *
 * @author ruoyi
 */
@Service
public class PetProfileService
{
    @Autowired
    private PetMemberPetMapper petMapper;

    @Autowired
    private MallConfigService configService;

    public List<PetMemberPet> list(Long memberId, boolean includeArchived)
    {
        return petMapper.selectByMemberId(memberId, includeArchived);
    }

    public PetMemberPet getOwned(Long memberId, Long petId)
    {
        if (petId == null)
        {
            return null;
        }
        PetMemberPet pet = petMapper.selectByIdAndMember(petId, memberId);
        if (pet == null)
        {
            throw new ForbiddenException("宠物档案不存在或无权访问");
        }
        return pet;
    }

    @Transactional(rollbackFor = Exception.class)
    public PetMemberPet create(Long memberId, PetProfileRequest request)
    {
        if (petMapper.countByMember(memberId) >= configService.petMax())
        {
            throw new BizException(ErrorCode.PET_1004,
                    "最多维护" + configService.petMax() + "个宠物档案");
        }
        PetMemberPet pet = new PetMemberPet();
        pet.setMemberId(memberId);
        apply(pet, request);
        pet.setStatus(request.status() == null ? 0 : request.status());
        petMapper.insert(pet);
        return petMapper.selectByIdAndMember(pet.getId(), memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetMemberPet update(Long memberId, Long petId, PetProfileRequest request)
    {
        PetMemberPet pet = getOwned(memberId, petId);
        if (pet.getStatus() != 0 && Integer.valueOf(0).equals(request.status())
                && petMapper.countByMember(memberId) >= configService.petMax())
        {
            throw new BizException(ErrorCode.PET_1004, "活跃宠物档案已达上限，请先归档其他档案");
        }
        apply(pet, request);
        if (request.status() != null)
        {
            pet.setStatus(request.status());
        }
        petMapper.update(pet);
        return petMapper.selectByIdAndMember(petId, memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void archive(Long memberId, Long petId)
    {
        getOwned(memberId, petId);
        petMapper.archive(petId, memberId);
    }

    private void apply(PetMemberPet pet, PetProfileRequest request)
    {
        if (request.birthday() != null && request.birthday().isAfter(LocalDate.now()))
        {
            throw new BizException(ErrorCode.PET_1001, "宠物生日不能晚于今天");
        }
        pet.setName(request.name().trim());
        pet.setSpecies(request.species());
        pet.setBreed(request.breed());
        pet.setBirthday(toDate(request.birthday()));
        pet.setWeight(request.weight());
        pet.setSterilized(request.sterilized() == null ? 0 : request.sterilized());
        pet.setAllergyNote(request.allergyNote());
    }

    public static Date toDate(LocalDate date)
    {
        return date == null ? null : Date.from(date.atStartOfDay(ZoneId.systemDefault()).toInstant());
    }
}
