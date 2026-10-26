package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.mall.domain.PetMessage;

/**
 * 站内消息 Mapper。
 *
 * @author ruoyi
 */
@Mapper
public interface PetMessageMapper
{
    int insert(PetMessage message);

    List<PetMessage> selectByMember(@Param("memberId") Long memberId, @Param("readFlag") Integer readFlag);

    long countUnread(@Param("memberId") Long memberId);

    int markRead(@Param("id") Long id, @Param("memberId") Long memberId);

    int markAllRead(@Param("memberId") Long memberId);
}
