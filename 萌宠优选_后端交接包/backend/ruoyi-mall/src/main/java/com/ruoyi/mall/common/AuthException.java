package com.ruoyi.mall.common;

/**
 * 未登录 / Token 失效。
 *
 * @author ruoyi
 */
public class AuthException extends BizException
{
    private static final long serialVersionUID = 1L;

    public AuthException()
    {
        super(ErrorCode.PET_2001);
    }

    public AuthException(String message)
    {
        super(ErrorCode.PET_2001, message);
    }
}
