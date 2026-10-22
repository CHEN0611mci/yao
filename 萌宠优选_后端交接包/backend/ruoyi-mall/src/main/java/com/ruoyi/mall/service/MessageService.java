package com.ruoyi.mall.service;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.mall.domain.PetMessage;
import com.ruoyi.mall.dto.MessagePageResponse;
import com.ruoyi.mall.event.MemberMessageEvent;
import com.ruoyi.mall.mapper.PetMessageMapper;

/**
 * 站内消息服务：分页查询、未读统计与已读标记。
 *
 * @author ruoyi
 */
@Service
public class MessageService
{
    @Autowired
    private PetMessageMapper messageMapper;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    public MessagePageResponse page(Long memberId, Integer readFlag, int pageNum, int pageSize)
    {
        PageHelper.startPage(pageNum, pageSize);
        List<PetMessage> list = messageMapper.selectByMember(memberId, readFlag);
        PageInfo<PetMessage> pageInfo = new PageInfo<>(list);
        return new MessagePageResponse(pageInfo.getPageNum(), pageInfo.getPageSize(), pageInfo.getTotal(),
                pageInfo.getList(), messageMapper.countUnread(memberId));
    }

    public long unread(Long memberId)
    {
        return messageMapper.countUnread(memberId);
    }

    public void markRead(Long memberId, Long messageId)
    {
        if (messageId != null)
        {
            messageMapper.markRead(messageId, memberId);
        }
    }

    public int markAllRead(Long memberId)
    {
        return messageMapper.markAllRead(memberId);
    }

    /**
     * 发布站内消息事件，事务提交后由监听器落库。
     */
    public void notify(Long memberId, String type, String title, String content, String targetUrl)
    {
        if (memberId == null)
        {
            return;
        }
        eventPublisher.publishEvent(new MemberMessageEvent(memberId, type, title, content, targetUrl));
    }
}
