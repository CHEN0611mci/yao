package com.ruoyi.mall.common;

import java.util.Collection;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.domain.PetMember;

/**
 * 会员 Token 服务：与后台若依 login_tokens:* 完全隔离。
 *
 * @author ruoyi
 */
@Component
public class MemberTokenService
{
    public static final String TOKEN_KEY_PREFIX = "member_tokens:";

    @Autowired
    private RedisCache redisCache;

    @Value("${mall.member-token-days:7}")
    private int tokenDays;

    public String createToken(PetMember member)
    {
        String token = UUID.randomUUID().toString().replace("-", "");
        MemberSession session = new MemberSession(member.getId(), member.getUsername(), member.getNickname(), token);
        redisCache.setCacheObject(TOKEN_KEY_PREFIX + token, session, tokenDays * 24 * 60, TimeUnit.MINUTES);
        return token;
    }

    public MemberSession getSession(String token)
    {
        if (StringUtils.isEmpty(token))
        {
            return null;
        }
        return redisCache.getCacheObject(TOKEN_KEY_PREFIX + token);
    }

    public MemberSession resolve(HttpServletRequest request)
    {
        String token = resolveToken(request);
        MemberSession session = getSession(token);
        if (session != null && redisCache.getExpire(TOKEN_KEY_PREFIX + token) < 24 * 60 * 60)
        {
            redisCache.expire(TOKEN_KEY_PREFIX + token, tokenDays, TimeUnit.DAYS);
        }
        return session;
    }

    public Long optionalMemberId(HttpServletRequest request)
    {
        MemberSession session = resolve(request);
        return session == null ? null : session.getMemberId();
    }

    public void logout(HttpServletRequest request)
    {
        String token = resolveToken(request);
        if (StringUtils.isNotEmpty(token))
        {
            redisCache.deleteObject(TOKEN_KEY_PREFIX + token);
        }
    }

    public void invalidateByMemberId(Long memberId)
    {
        Collection<String> keys = redisCache.keys(TOKEN_KEY_PREFIX + "*");
        if (keys == null || keys.isEmpty())
        {
            return;
        }
        for (String key : keys)
        {
            MemberSession session = redisCache.getCacheObject(key);
            if (session != null && memberId.equals(session.getMemberId()))
            {
                redisCache.deleteObject(key);
            }
        }
    }

    public static String resolveToken(HttpServletRequest request)
    {
        String token = request.getHeader("Authorization");
        if (StringUtils.isNotEmpty(token) && token.startsWith("Bearer "))
        {
            token = token.substring(7).trim();
        }
        return token;
    }

    public static String maskPhone(String phone)
    {
        if (StringUtils.isEmpty(phone) || phone.length() < 7)
        {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }
}
