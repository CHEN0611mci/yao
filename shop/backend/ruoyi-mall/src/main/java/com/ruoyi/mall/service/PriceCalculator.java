package com.ruoyi.mall.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collections;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * 一期计价引擎：商品总额 → 运费 → 应付，金额统一两位小数。
 *
 * @author ruoyi
 */
@Component
public class PriceCalculator
{
    public CalcResult calculate(List<Line> lines, BigDecimal freeThreshold, BigDecimal freightFee)
    {
        List<Line> safeLines = lines == null ? Collections.emptyList() : lines;
        BigDecimal total = BigDecimal.ZERO;
        for (Line line : safeLines)
        {
            BigDecimal price = line.price() == null ? BigDecimal.ZERO : line.price();
            int quantity = line.quantity() == null ? 0 : line.quantity();
            total = total.add(price.multiply(BigDecimal.valueOf(quantity)));
        }
        total = money(total);
        BigDecimal threshold = freeThreshold == null ? BigDecimal.ZERO : freeThreshold;
        BigDecimal fee = freightFee == null ? BigDecimal.ZERO : freightFee;
        boolean freeShipping = total.compareTo(BigDecimal.ZERO) == 0 || total.compareTo(threshold) >= 0;
        BigDecimal freight = freeShipping ? BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP) : money(fee);
        BigDecimal payAmount = money(total.add(freight));
        return new CalcResult(total, BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP), freight, payAmount, freeShipping);
    }

    public static BigDecimal money(BigDecimal value)
    {
        return (value == null ? BigDecimal.ZERO : value).setScale(2, RoundingMode.HALF_UP);
    }

    public record Line(BigDecimal price, Integer quantity)
    {
    }

    public record CalcResult(BigDecimal totalAmount, BigDecimal discountAmount, BigDecimal freight,
            BigDecimal payAmount, boolean freeShipping)
    {
    }
}
