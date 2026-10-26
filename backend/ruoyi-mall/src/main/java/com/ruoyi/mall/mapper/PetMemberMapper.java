package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetMember;

/**
 * 会员 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetMemberMapper
{
    PetMember selectByUsername(@Param("username") String username);

    PetMember selectByPhone(@Param("phone") String phone);

    PetMember selectById(@Param("id") Long id);

    int insert(PetMember member);

    int updateProfile(PetMember member);

    int changePassword(@Param("id") Long id, @Param("previous") String previous, @Param("password") String password);

    int updateStatus(@Param("id") Long id, @Param("status") Integer status);

    List<PetMember> selectList(@Param("keyword") String keyword, @Param("status") Integer status);

    long countAll();
}
