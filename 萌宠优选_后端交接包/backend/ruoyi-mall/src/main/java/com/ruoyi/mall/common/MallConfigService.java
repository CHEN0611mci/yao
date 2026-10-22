package com.ruoyi.mall.common;

import java.math.BigDecimal;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 商城参数读取（sys_config 中 mall.* 键），带安全默认值。
 *
 * @author ruoyi
 */
@Service
public class MallConfigService
{
    @Autowired
    private ISysConfigService configService;

    public String getString(String key, String defaultValue)
    {
        String value = configService.selectConfigByKey(key);
        return StringUtils.isEmpty(value) ? defaultValue : value.trim();
    }

    public int getInt(String key, int defaultValue)
    {
        String value = getString(key, null);
        if (StringUtils.isEmpty(value))
        {
            return defaultValue;
        }
        try
        {
            return Integer.parseInt(value);
        }
        catch (NumberFormatException e)
        {
            return defaultValue;
        }
    }

    public BigDecimal getDecimal(String key, BigDecimal defaultValue)
    {
        String value = getString(key, null);
        if (StringUtils.isEmpty(value))
        {
            return defaultValue;
        }
        try
        {
            return new BigDecimal(value);
        }
        catch (NumberFormatException e)
        {
            return defaultValue;
        }
    }

    public int payTimeoutMinutes()
    {
        return Math.max(1, getInt("mall.pay-timeout-minutes", 15));
    }

    public int autoConfirmDays()
    {
        return Math.max(1, getInt("mall.auto-confirm-days", 10));
    }

    public int petMax()
    {
        return Math.max(1, getInt("mall.pet-max", 5));
    }

    public int addressMax()
    {
        return Math.max(1, getInt("mall.address-max", 20));
    }

    public int cartMaxSku()
    {
        return Math.max(1, getInt("mall.cart-max-sku", 200));
    }

    public int buyLimitDefault()
    {
        return Math.max(1, getInt("mall.buy-limit-default", 99));
    }

    public BigDecimal freightFreeThreshold()
    {
        return getDecimal("mall.freight-free-threshold", new BigDecimal("99.00"));
    }

    public BigDecimal freightFee()
    {
        return getDecimal("mall.freight-fee", new BigDecimal("10.00"));
    }

    public String payCallbackToken()
    {
        return getString("mall.pay-callback-token", "sandbox-internal-token");
    }
}
