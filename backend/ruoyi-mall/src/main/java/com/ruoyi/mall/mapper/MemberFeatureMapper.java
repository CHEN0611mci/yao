package com.ruoyi.mall.mapper;

import java.util.List;
import org.apache.ibatis.annotations.*;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.dto.NotificationPreference;

@Mapper
public interface MemberFeatureMapper
{
    @Select("SELECT order_notifications, system_notifications FROM pet_member_preference WHERE member_id=#{memberId}")
    NotificationPreference preference(@Param("memberId") Long memberId);
    @Insert("INSERT INTO pet_member_preference(member_id,order_notifications,system_notifications) VALUES(#{memberId},#{value.orderNotifications},#{value.systemNotifications}) ON DUPLICATE KEY UPDATE order_notifications=VALUES(order_notifications),system_notifications=VALUES(system_notifications),update_time=NOW()")
    int savePreference(@Param("memberId") Long memberId, @Param("value") NotificationPreference value);
    @Select("SELECT i.* FROM pet_member_favorite f JOIN pet_item i ON i.id=f.item_id WHERE f.member_id=#{memberId} ORDER BY f.create_time DESC,f.item_id DESC")
    List<PetItem> favorites(@Param("memberId") Long memberId);
    @Select("SELECT COUNT(*) FROM pet_member_favorite WHERE member_id=#{memberId}")
    int favoriteCount(@Param("memberId") Long memberId);
    @Select("SELECT COUNT(*) FROM pet_member_favorite WHERE member_id=#{memberId} AND item_id=#{itemId}")
    int isFavorite(@Param("memberId") Long memberId,@Param("itemId") Long itemId);
    @Insert("INSERT INTO pet_member_favorite(member_id,item_id) VALUES(#{memberId},#{itemId}) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id)")
    int addFavorite(@Param("memberId") Long memberId,@Param("itemId") Long itemId);
    @Delete("DELETE FROM pet_member_favorite WHERE member_id=#{memberId} AND item_id=#{itemId}")
    int removeFavorite(@Param("memberId") Long memberId,@Param("itemId") Long itemId);
}
