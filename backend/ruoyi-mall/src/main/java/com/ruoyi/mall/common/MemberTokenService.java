package com.ruoyi.mall.common;

import java.util.UUID;
import java.util.List;
import java.util.ArrayList;
import java.util.Comparator;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.domain.PetMember;
import com.ruoyi.mall.mapper.PetMemberMapper;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

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
    @Autowired private PetMemberMapper memberMapper;
    @Autowired private MemberSessionIndex sessionIndex;

    @Value("${mall.member-token-days:7}")
    private int tokenDays;

    public String createToken(PetMember member)
    {
        String token = UUID.randomUUID().toString().replace("-", "");
        MemberSession session = new MemberSession(member.getId(), member.getUsername(), member.getNickname(), token);
        session.setSessionId(UUID.randomUUID().toString());
        String client = "未知客户端";
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attributes)
        {
            String ua = attributes.getRequest().getHeader("User-Agent");
            if (ua != null && !ua.isBlank()) client = ua.substring(0, Math.min(ua.length(),200));
        }
        session.setClient(client);
        sessionIndex.create(session, TimeUnit.DAYS.toMillis(tokenDays));
        return token;
    }

    public MemberSession getSession(String token)
    {
        if (StringUtils.isEmpty(token))
        {
            return null;
        }
        MemberSession session = sessionIndex.read(token);
        if (session != null)
        {
            PetMember member = memberMapper.selectById(session.getMemberId());
            if (member == null || Integer.valueOf(1).equals(member.getStatus()))
            {
                sessionIndex.remove(session);
                throw new BizException(member == null ? ErrorCode.PET_2001 : ErrorCode.PET_2004);
            }
        }
        return session;
    }

    public MemberSession resolve(HttpServletRequest request)
    {
        String token = resolveToken(request);
        MemberSession session = getSession(token);
        if (session != null && redisCache.getExpire(TOKEN_KEY_PREFIX + token) < 24 * 60 * 60)
        {
            if (!sessionIndex.refresh(session, TimeUnit.DAYS.toMillis(tokenDays))) return null;
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
            MemberSession session = sessionIndex.read(token);
            if (session != null) sessionIndex.remove(session);
        }
    }

    public void invalidateByMemberId(Long memberId)
    {
        sessionIndex.removeOthers(memberId, null);
    }

    public record SessionView(String id, String client, Long loginAt, Long expiresAt, boolean current) { }
    static String sessionId(MemberSession session)
    {
        return session.getSessionId() != null ? session.getSessionId()
                : UUID.nameUUIDFromBytes(("session:" + session.getToken()).getBytes(StandardCharsets.UTF_8)).toString();
    }
    public List<SessionView> sessions(Long memberId, String currentToken)
    {
        List<SessionView> result = new ArrayList<>();
        for (var active : sessionIndex.active(memberId))
        {
            MemberSession session = active.session();
            result.add(new SessionView(sessionId(session), session.getClient() == null ? "历史会话" : session.getClient(),
                    session.getLoginAt(),System.currentTimeMillis() + active.ttlMillis(), session.getToken().equals(currentToken)));
        }
        result.sort(Comparator.comparing(SessionView::current).reversed().thenComparing(SessionView::loginAt, Comparator.nullsLast(Comparator.reverseOrder())));
        return result;
    }
    public boolean revoke(Long memberId,String id)
    {
        MemberSession session = sessionIndex.owned(memberId, id);
        if (session != null && sessionIndex.remove(session)) return true;
        throw new ForbiddenException("会话不存在或无权访问");
    }
    public int revokeOthers(Long memberId,String currentToken)
    {
        return sessionIndex.removeOthers(memberId, currentToken);
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
