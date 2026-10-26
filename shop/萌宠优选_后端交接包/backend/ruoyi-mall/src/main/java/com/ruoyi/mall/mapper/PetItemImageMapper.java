package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetItemImage;

/**
 * 商品图片 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetItemImageMapper
{
    List<PetItemImage> selectByItemId(@Param("itemId") Long itemId);

    int insert(PetItemImage image);

    int deleteByItemId(@Param("itemId") Long itemId);
}
