package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetCategory;

/**
 * 商品分类 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetCategoryMapper
{
    List<PetCategory> selectList(@Param("status") Integer status);

    PetCategory selectById(@Param("id") Long id);

    int countChildren(@Param("parentId") Long parentId);

    int countItems(@Param("categoryId") Long categoryId);

    int insert(PetCategory category);

    int update(PetCategory category);

    int delete(@Param("id") Long id);
}
