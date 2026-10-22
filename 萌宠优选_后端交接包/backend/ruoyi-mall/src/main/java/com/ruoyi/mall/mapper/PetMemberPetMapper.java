package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetMemberPet;

/**
 * 宠物档案 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetMemberPetMapper
{
    List<PetMemberPet> selectByMemberId(@Param("memberId") Long memberId,
            @Param("includeArchived") boolean includeArchived);

    PetMemberPet selectByIdAndMember(@Param("id") Long id, @Param("memberId") Long memberId);

    int countByMember(@Param("memberId") Long memberId);

    int insert(PetMemberPet pet);

    int update(PetMemberPet pet);

    int archive(@Param("id") Long id, @Param("memberId") Long memberId);
}
