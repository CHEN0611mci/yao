package com.ruoyi.mall.service;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.mall.common.*;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.dto.NotificationPreference;
import com.ruoyi.mall.mapper.MemberFeatureMapper;
import com.ruoyi.mall.mapper.PetItemMapper;

@Service
public class MemberFeatureService
{
    @Autowired private MemberFeatureMapper mapper;
    @Autowired private PetItemMapper items;
    @Autowired private MemberWriteLock memberLock;
    @Autowired private CatalogPolicy policy;
    @Autowired private MallConfigService config;

    public NotificationPreference preference(Long memberId)
    {
        NotificationPreference value = mapper.preference(memberId);
        return value == null ? new NotificationPreference(true, true) : value;
    }
    @Transactional(rollbackFor=Exception.class)
    public NotificationPreference savePreference(Long memberId, NotificationPreference value)
    {
        memberLock.acquire(memberId);
        mapper.savePreference(memberId,value);
        return value;
    }
    public boolean accepts(Long memberId, String type)
    {
        var value = preference(memberId);
        return "ORDER".equals(type) ? value.orderNotifications() : value.systemNotifications();
    }
    public PageResult<PetItem> favorites(Long memberId, int page, int size)
    {
        PageHelper.startPage(Math.max(1,page), Math.min(50,Math.max(1,size)));
        var result = new PageInfo<>(mapper.favorites(memberId));
        result.getList().forEach(item -> { item.setCostPrice(null); item.setDetail(null); });
        return PageResult.of(result);
    }
    public boolean isFavorite(Long memberId, Long itemId) { return mapper.isFavorite(memberId,itemId)>0; }
    @Transactional(rollbackFor=Exception.class)
    public void addFavorite(Long memberId, Long itemId)
    {
        memberLock.acquire(memberId);
        if (isFavorite(memberId,itemId)) return;
        PetItem item = items.selectSellableById(itemId);
        if(item==null) throw new BizException(ErrorCode.PET_3003);
        policy.checkSale(item);
        if(mapper.favoriteCount(memberId)>=Math.max(1,config.getInt("mall.favorite-max",500)))
            throw new BizException(ErrorCode.PET_1004,"收藏数量已达上限，请先移除部分收藏");
        mapper.addFavorite(memberId,itemId);
    }
    public void removeFavorite(Long memberId,Long itemId) { mapper.removeFavorite(memberId,itemId); }
}
