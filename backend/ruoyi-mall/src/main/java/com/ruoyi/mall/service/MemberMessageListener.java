package com.ruoyi.mall.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import com.ruoyi.mall.domain.PetMessage;
import com.ruoyi.mall.event.MemberMessageEvent;
import com.ruoyi.mall.mapper.PetMessageMapper;

/**
 * 会员消息监听器：仅在业务事务提交后写入，避免回滚产生脏消息。
 *
 * @author ruoyi
 */
@Component
public class MemberMessageListener
{
    @Autowired
    private PetMessageMapper messageMapper;
    @Autowired private MemberFeatureService memberFeatures;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
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
