package com.ruoyi.mall.common;

/**
 * 接口限流异常。
 *
 * @author ruoyi
 */
public class RateLimitException extends BizException
{
    private static final long serialVersionUID = 1L;

    private final long retryAfterSeconds;

    public RateLimitException(long retryAfterSeconds)
    {
        super(ErrorCode.PET_4290);
        this.retryAfterSeconds = Math.max(1L, retryAfterSeconds);
    }

    public long getRetryAfterSeconds()
    {
        return retryAfterSeconds;
    }
}
