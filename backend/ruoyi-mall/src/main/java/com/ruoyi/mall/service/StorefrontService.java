package com.ruoyi.mall.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import com.alibaba.fastjson2.JSON;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.mall.common.MallConfigService;

/** Small storefront content is managed through the existing system parameter screen. */
@Service
public class StorefrontService
{
    @Autowired private MallConfigService config;
    public record Banner(String title, String subtitle, String image, String path, int sort,
            Boolean enabled, LocalDateTime startsAt, LocalDateTime endsAt) { }

    public Map<String, Object> settings()
    {
        List<Banner> banners = new ArrayList<>();
        String raw = config.getString("mall.home.banners", "");
        try { if (!raw.isEmpty()) banners.addAll(JSON.parseArray(raw, Banner.class)); }
        catch (RuntimeException ignored) { /* Malformed optional content must not break the shop. */ }
        if (banners.isEmpty()) banners.add(new Banner("它的小日常，我们的大认真。", "从第一口好粮，到每一次撒欢。为毛孩子挑好物，也为陪伴添一点幸福。", "/images/companions.svg", "/items", 0, true, null, null));
        LocalDateTime now = LocalDateTime.now();
        banners.removeIf(b -> b == null || Boolean.FALSE.equals(b.enabled())
                || (b.startsAt() != null && b.startsAt().isAfter(now)) || (b.endsAt() != null && !b.endsAt().isAfter(now)));
        banners.sort(Comparator.comparingInt(Banner::sort));
        return Map.of("banners", banners,
                "promises", config.getString("mall.home.promises", "正品保障（课程演示）,食品效期说明,破损联系项目客服,服务规则请见用户协议").split("[,，]"),
                "hotKeywords", config.getString("mall.search.hot-keywords", "猫粮,狗粮,猫砂,零食").split("[,，]"),
                "support", config.getString("mall.support.description", "本商城为教学沙箱。商品与订单问题可在下方提交意见反馈，项目管理员通过后台操作日志处理。"),
                "version", "1.1.0");
    }
}
