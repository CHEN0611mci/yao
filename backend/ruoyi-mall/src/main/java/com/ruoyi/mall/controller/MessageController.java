package com.ruoyi.mall.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.dto.MessagePageResponse;
import com.ruoyi.mall.service.MessageService;

/**
 * 会员消息中心接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/member/messages")
public class MessageController
{
    @Autowired
    private MessageService messageService;

    @GetMapping
    public Result<MessagePageResponse> list(
            @RequestParam(value = "readFlag", required = false) Integer readFlag,
            @RequestParam(value = "pageNum", defaultValue = "1") int pageNum,
            @RequestParam(value = "pageSize", defaultValue = "10") int pageSize)
    {
        int safePageNum = Math.max(pageNum, 1);
        int safePageSize = Math.min(Math.max(pageSize, 1), 100);
        return Result.success(messageService.page(MemberContext.require(), readFlag, safePageNum, safePageSize));
    }

    @GetMapping("/unread-count")
    public Result<Long> unreadCount()
    {
        return Result.success(messageService.unread(MemberContext.require()));
    }

    @PutMapping("/{id}/read")
    public Result<Void> markRead(@PathVariable("id") Long id)
    {
        messageService.markRead(MemberContext.require(), id);
        return Result.success();
    }

    @PutMapping("/read-all")
    public Result<Integer> markAllRead()
    {
        return Result.success("全部消息已读", messageService.markAllRead(MemberContext.require()));
    }
}
