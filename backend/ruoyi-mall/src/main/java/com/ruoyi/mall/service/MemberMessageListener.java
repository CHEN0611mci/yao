package com.ruoyi.mall.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import com.ruoyi.mall.domain.PetMessage;
import com.ruoyi.mall.event.MemberMessageEvent;
import com.ruoyi.mall.mapper.PetMessageMapper;

/**
 * 会员消息监听器：提交前使用业务事务的连接写入，与业务一起提交或回滚。
 *
 * @author ruoyi
 */
@Component
public class MemberMessageListener
{
    @Autowired
    private PetMessageMapper messageMapper;
    @Autowired private MemberFeatureService memberFeatures;

    // AFTER_COMMIT + REQUIRES_NEW retains the outer connection while waiting
    // for another one; concurrent commits can exhaust the entire connection pool.
    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT, fallbackExecution = true)
    public void onMemberMessage(MemberMessageEvent event)
    {
        if (event == null || event.memberId() == null)
        {
            return;
        }
        PetMessage message = new PetMessage();
        if (!memberFeatures.accepts(event.memberId(),event.type())) return;
        message.setMemberId(event.memberId());
        message.setType(event.type());
        message.setTitle(event.title());
        message.setContent(event.content());
        message.setTargetUrl(event.targetUrl());
        message.setReadFlag(0);
        messageMapper.insert(message);
    }
}
