package com.ruoyi.mall.common;

import java.time.Duration;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 基于 Redis 的固定窗口限流：登录、下单、回调。
 *
 * @author ruoyi
 */
@Component
public class MallRateLimiter
{
    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    public void check(String scene, String identity, int limit, int seconds)
    {
        String key = "mall:rate:" + scene + ":" + identity;
        Long count = stringRedisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L)
        {
            stringRedisTemplate.expire(key, Duration.ofSeconds(seconds));
        }
        if (count != null && count > limit)
        {
            Long ttl = stringRedisTemplate.getExpire(key, TimeUnit.SECONDS);
            throw new RateLimitException(ttl == null || ttl <= 0 ? seconds : ttl);
        }
    }
}
