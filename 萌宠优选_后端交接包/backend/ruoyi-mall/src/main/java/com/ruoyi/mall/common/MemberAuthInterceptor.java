package com.ruoyi.mall.common;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 会员鉴权拦截器：校验 Redis 中的 member_tokens，并把 memberId 写入线程上下文。
 *
 * @author ruoyi
 */
@Component
public class MemberAuthInterceptor implements HandlerInterceptor
{
    @Autowired
    private MemberTokenService memberTokenService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
    {
        MemberSession session = memberTokenService.resolve(request);
        if (session == null)
        {
            throw new AuthException();
        }
        MemberContext.set(session.getMemberId());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex)
    {
        MemberContext.clear();
    }
}
