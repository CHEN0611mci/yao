package com.ruoyi.mall.common;

/**
 * 幂等键命中：返回已有结果而不是失败。
 *
 * @author ruoyi
 */
public class DuplicateRequestException extends BizException
{
    private static final long serialVersionUID = 1L;

    public DuplicateRequestException(Object data)
    {
        super(ErrorCode.PET_4001, ErrorCode.PET_4001.getMessage(), data);
    }
}
