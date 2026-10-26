package com.ruoyi.mall.common;

import java.io.Serializable;

/**
 * 会员登录态，存储于 Redis member_tokens:*。
 *
 * @author ruoyi
 */
public class MemberSession implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long memberId;
    private String username;
    private String nickname;
    private String token;
    private Long loginAt;
    private String sessionId;
    private String client;
    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }
    public String getClient() { return client; }
    public void setClient(String client) { this.client = client; }

    public MemberSession()
    {
    }

    public MemberSession(Long memberId, String username, String nickname, String token)
    {
        this.memberId = memberId;
        this.username = username;
        this.nickname = nickname;
        this.token = token;
        this.loginAt = System.currentTimeMillis();
    }

    public Long getMemberId()
    {
        return memberId;
    }

    public void setMemberId(Long memberId)
    {
        this.memberId = memberId;
    }

    public String getUsername()
    {
        return username;
    }

    public void setUsername(String username)
    {
        this.username = username;
    }

    public String getNickname()
    {
        return nickname;
    }

    public void setNickname(String nickname)
    {
        this.nickname = nickname;
    }

    public String getToken()
    {
        return token;
    }

    public void setToken(String token)
    {
        this.token = token;
    }

    public Long getLoginAt()
    {
        return loginAt;
    }

    public void setLoginAt(Long loginAt)
    {
        this.loginAt = loginAt;
    }
}
