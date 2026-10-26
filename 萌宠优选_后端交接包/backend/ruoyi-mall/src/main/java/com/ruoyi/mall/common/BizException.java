package com.ruoyi.mall.common;

/**
 * 业务异常：由全局异常处理器转换为统一错误响应。
 *
 * @author ruoyi
 */
public class BizException extends RuntimeException
{
    private static final long serialVersionUID = 1L;

    private final ErrorCode errorCode;
    private final Object data;

    public BizException(ErrorCode errorCode)
    {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
        this.data = null;
    }

    public BizException(ErrorCode errorCode, String message)
    {
        super(message);
        this.errorCode = errorCode;
        this.data = null;
    }

    public BizException(ErrorCode errorCode, String message, Object data)
    {
        super(message);
        this.errorCode = errorCode;
        this.data = data;
    }

    public BizException(ErrorCode errorCode, String message, Throwable cause)
    {
        super(message, cause);
        this.errorCode = errorCode;
        this.data = null;
    }

    public ErrorCode getErrorCode()
    {
        return errorCode;
    }

    public Object getData()
    {
        return data;
    }
}
