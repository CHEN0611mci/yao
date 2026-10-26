package com.ruoyi.mall.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.MemberTokenService;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.dto.MockPayRequest;
import com.ruoyi.mall.dto.PayCallbackRequest;
import com.ruoyi.mall.dto.PaymentResponse;
import com.ruoyi.mall.service.PaymentService;

/**
 * 支付接口：沙箱支付、渠道回调与支付记录查询。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/pay")
public class PayController
{
    @Autowired
    private PaymentService paymentService;

    @Autowired
    private MallConfigService mallConfigService;

    @PostMapping("/mock")
    public Result<PaymentResponse> mockPay(@Valid @RequestBody MockPayRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey)
    {
        return Result.success(paymentService.mockPay(MemberContext.require(), request, idempotencyKey));
    }

    @PostMapping("/callback")
    public Result<PaymentResponse> callback(@Valid @RequestBody PayCallbackRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
            HttpServletRequest servletRequest)
    {
        verifyCallbackToken(servletRequest);
        return Result.success(paymentService.callback(request, idempotencyKey));
    }

    @GetMapping("/{orderNo}")
    public Result<PaymentResponse> query(@PathVariable("orderNo") String orderNo)
    {
        return Result.success(paymentService.query(MemberContext.require(), orderNo));
    }

    /**
     * 一期沙箱回调使用内部令牌（Authorization: Bearer &lt;mall.pay-callback-token&gt;）。
     */
    private void verifyCallbackToken(HttpServletRequest request)
    {
        String token = MemberTokenService.resolveToken(request);
        String expected = mallConfigService.payCallbackToken();
        if (StringUtils.isEmpty(token) || !expected.equals(token.trim()))
        {
            throw new BizException(ErrorCode.PET_1005);
        }
    }
}
