package com.ruoyi.mall.dto;

import java.util.List;
import com.ruoyi.mall.domain.PetMessage;

/**
 * 会员消息分页结果（附带未读总数）。
 *
 * @author ruoyi
 */
public record MessagePageResponse(int pageNum, int pageSize, long total, List<PetMessage> list, long unread)
{
}
