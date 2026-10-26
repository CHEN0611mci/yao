package com.ruoyi.mall.common;

/**
 * 当前会员上下文（由 MemberAuthInterceptor 写入，请求结束清理）。
 *
 * @author ruoyi
 */
public final class MemberContext
{
    private static final ThreadLocal<Long> MEMBER_ID = new ThreadLocal<>();

    private MemberContext()
    {
    }

    public static void set(Long memberId)
    {
        MEMBER_ID.set(memberId);
    }

    public static Long get()
    {
        return MEMBER_ID.get();
    }

    public static Long require()
    {
        Long memberId = MEMBER_ID.get();
        if (memberId == null)
        {
            throw new AuthException();
        }
        return memberId;
    }

    public static void clear()
    {
        MEMBER_ID.remove();
    }
}
