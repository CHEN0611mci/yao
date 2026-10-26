package com.ruoyi.mall.common;

import java.io.Serializable;
import java.util.UUID;
import org.slf4j.MDC;

/**
 * 商城统一响应：{code,message,data,traceId}。
 *
 * @author ruoyi
 */
public class Result<T> implements Serializable
{
    private static final long serialVersionUID = 1L;

    public static final int SUCCESS = 200;

    private int code;
    private String message;
    private T data;
    private String traceId;
    private String errorCode;

    public Result()
    {
    }

    public Result(int code, String message, T data)
    {
        this.code = code;
        this.message = message;
        this.data = data;
        this.traceId = currentTraceId();
        this.errorCode = code == SUCCESS ? null : "PET-" + code;
    }

    public static <T> Result<T> success()
    {
        return new Result<>(SUCCESS, "success", null);
    }

    public static <T> Result<T> success(T data)
    {
        return new Result<>(SUCCESS, "success", data);
    }

    public static <T> Result<T> success(String message, T data)
    {
        return new Result<>(SUCCESS, message, data);
    }

    public static <T> Result<T> failure(ErrorCode errorCode)
    {
        return new Result<>(errorCode.getCode(), errorCode.getMessage(), null);
    }

    public static <T> Result<T> failure(ErrorCode errorCode, String message)
    {
        return new Result<>(errorCode.getCode(), message, null);
    }

    public static <T> Result<T> failure(ErrorCode errorCode, String message, T data)
    {
        return new Result<>(errorCode.getCode(), message, data);
    }

    public static <T> Result<T> failure(int code, String message, T data)
    {
        return new Result<>(code, message, data);
    }

    private static String currentTraceId()
    {
        String traceId = MDC.get("traceId");
        return traceId == null ? UUID.randomUUID().toString().replace("-", "") : traceId;
    }

    public int getCode()
    {
        return code;
    }

    public void setCode(int code)
    {
        this.code = code;
    }

    public String getMessage()
    {
        return message;
    }

    public void setMessage(String message)
    {
        this.message = message;
    }

    public T getData()
    {
        return data;
    }

    public void setData(T data)
    {
        this.data = data;
    }

    public String getTraceId()
    {
        return traceId;
    }

    public void setTraceId(String traceId)
    {
        this.traceId = traceId;
    }

    public String getErrorCode()
    {
        return errorCode;
    }

    public void setErrorCode(String errorCode)
    {
        this.errorCode = errorCode;
    }
}
