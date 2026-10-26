package com.ruoyi.mall.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import com.ruoyi.mall.common.MemberAuthInterceptor;

/**
 * 商城 Web 配置：注册会员鉴权拦截器与定时任务。
 *
 * @author ruoyi
 */
@Configuration
@EnableScheduling
public class MallWebConfig implements WebMvcConfigurer
{
    @Autowired
    private MemberAuthInterceptor memberAuthInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry)
    {
        registry.addInterceptor(memberAuthInterceptor)
                .addPathPatterns("/api/member/**", "/api/cart/**", "/api/checkout/**",
                        "/api/orders/**", "/api/pay/**")
                .excludePathPatterns("/api/member/register", "/api/member/login", "/api/pay/callback");
    }
}
