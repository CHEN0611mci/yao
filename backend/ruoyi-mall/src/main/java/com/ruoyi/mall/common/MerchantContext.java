package com.ruoyi.mall.common;

import com.ruoyi.common.utils.SecurityUtils;

/**
 * 后台商家上下文：商家账号通过所属部门（dept_id）绑定 merchant_id。
 *
 * @author ruoyi
 */
public final class MerchantContext
{
    private MerchantContext()
    {
    }

    /**
     * 当前登录商家账号对应的 merchant_id。
     *
     * @return 商家 ID
     */
    public static Long requireMerchantId()
    {
        Long deptId = SecurityUtils.getDeptId();
        if (deptId == null)
        {
            throw new ForbiddenException("当前账号未绑定商家，请联系管理员");
        }
        return deptId;
    }

    /**
     * 当前后台操作人登录名，用于发货/审核留痕。
     *
     * @return 登录名
     */
    public static String operator()
    {
        return SecurityUtils.getUsername();
    }
}
