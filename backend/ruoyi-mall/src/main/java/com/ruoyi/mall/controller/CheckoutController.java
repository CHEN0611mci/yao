package com.ruoyi.mall.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.dto.CheckoutPreviewRequest;
import com.ruoyi.mall.dto.PreviewResponse;
import com.ruoyi.mall.service.CheckoutService;

/**
 * 结算试算接口。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/checkout")
public class CheckoutController
{
    @Autowired
    private CheckoutService checkoutService;

    @PostMapping("/preview")
    public Result<PreviewResponse> preview(@RequestBody(required = false) CheckoutPreviewRequest request)
    {
        CheckoutPreviewRequest body = request == null ? new CheckoutPreviewRequest(null, null) : request;
        return Result.success(checkoutService.preview(MemberContext.require(), body));
    }
}
