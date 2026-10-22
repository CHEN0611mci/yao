package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetCartItem;

/**
 * 购物车 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetCartItemMapper
{
    List<PetCartItem> selectByMemberId(@Param("memberId") Long memberId);

    List<PetCartItem> selectChecked(@Param("memberId") Long memberId);

    PetCartItem selectByIdAndMember(@Param("id") Long id, @Param("memberId") Long memberId);

    PetCartItem selectByMemberAndSku(@Param("memberId") Long memberId, @Param("skuId") Long skuId);

    int countByMember(@Param("memberId") Long memberId);

    int insert(PetCartItem item);

    int update(PetCartItem item);

    int delete(@Param("id") Long id, @Param("memberId") Long memberId);

    int deleteByMemberAndSkus(@Param("memberId") Long memberId, @Param("skuIds") List<Long> skuIds);
}
