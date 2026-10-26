package com.ruoyi.mall.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.domain.PetItem;

@Service
public class CatalogPolicy
{
    @Autowired private MallConfigService config;
    public void checkText(String text)
    {
        String content = text == null ? "" : text.replaceAll("<[^>]*>", "");
        for (String word : config.getString("mall.catalog.blocked-words", "活体,野生动物制品,人用药品,包治百病,永久治愈").split("[,，]"))
            if (!word.isBlank() && content.contains(word.trim()))
                throw new BizException(ErrorCode.PET_7001, "内容命中禁售或不当宣称规则，请调整后重试");
    }
    public void checkSale(PetItem item)
    {
        checkText(item.getTitle() + " " + item.getSubtitle() + " " + item.getDetail());
        if (Integer.valueOf(1).equals(item.getIsPrescription()))
            throw new BizException(ErrorCode.PET_7002, "本期教学商城不销售处方商品");
    }
}
