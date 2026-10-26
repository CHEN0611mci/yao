package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetAddress;

/**
 * 收货地址 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetAddressMapper
{
    List<PetAddress> selectByMemberId(@Param("memberId") Long memberId);

    PetAddress selectByIdAndMember(@Param("id") Long id, @Param("memberId") Long memberId);

    int countByMember(@Param("memberId") Long memberId);

    int insert(PetAddress address);

    int update(PetAddress address);

    int delete(@Param("id") Long id, @Param("memberId") Long memberId);

    int clearDefault(@Param("memberId") Long memberId, @Param("addressId") Long addressId);

    int setDefault(@Param("id") Long id, @Param("memberId") Long memberId);

    int countActiveOrderByAddress(@Param("memberId") Long memberId, @Param("addressId") Long addressId);
}
