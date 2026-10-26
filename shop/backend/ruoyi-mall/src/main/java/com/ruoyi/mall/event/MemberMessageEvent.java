package com.ruoyi.mall.event;

/**
 * 站内消息事件，在业务事务提交后异步落库。
 *
 * @author ruoyi
 */
public record MemberMessageEvent(Long memberId, String type, String title, String content, String targetUrl)
{
}
