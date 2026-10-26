package com.ruoyi.mall.common;

/**
 * 水平或垂直越权。
 *
 * @author ruoyi
 */
public class ForbiddenException extends BizException
{
    private static final long serialVersionUID = 1L;

    public ForbiddenException()
    {
        super(ErrorCode.PET_2003);
    }

    public ForbiddenException(String message)
    {
        super(ErrorCode.PET_2003, message);
    }
}
