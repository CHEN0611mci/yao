package com.ruoyi.mall.controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.mall.common.MemberContext;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.common.Result;
import com.ruoyi.mall.domain.PetOrder;
import com.ruoyi.mall.dto.CancelRequest;
import com.ruoyi.mall.dto.CancelResponse;
import com.ruoyi.mall.dto.ConfirmResponse;
import com.ruoyi.mall.dto.OrderSubmitResponse;
import com.ruoyi.mall.dto.SubmitOrderRequest;
import com.ruoyi.mall.dto.OrderAddressRequest;
import com.ruoyi.mall.service.CheckoutService;
import com.ruoyi.mall.service.OrderService;

/**
 * 会员订单接口：提交、列表、详情、取消与确认收货。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController
{
    @Autowired
    private OrderService orderService;

    @Autowired
    private CheckoutService checkoutService;

    @PostMapping
    public Result<OrderSubmitResponse> submit(@Valid @RequestBody SubmitOrderRequest request)
    {
        OrderSubmitResponse response = checkoutService.submit(MemberContext.require(), request);
        return Result.success(response.duplicated() ? "重复请求，已返回原订单" : "下单成功", response);
    }

    @GetMapping
    public Result<PageResult<PetOrder>> list(
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "pageNum", defaultValue = "1") int pageNum,
            @RequestParam(value = "pageSize", defaultValue = "10") int pageSize)
    {
        int safePageNum = Math.max(pageNum, 1);
        int safePageSize = Math.min(Math.max(pageSize, 1), 100);
        return Result.success(orderService.memberList(MemberContext.require(), status, keyword, safePageNum, safePageSize));
    }

    @GetMapping("/{orderNo}")
    public Result<PetOrder> detail(@PathVariable("orderNo") String orderNo)
    {
        return Result.success(orderService.memberDetail(MemberContext.require(), orderNo));
    }

    @PostMapping("/{orderNo}/cancel")
    public Result<CancelResponse> cancel(@PathVariable("orderNo") String orderNo,
            @Valid @RequestBody(required = false) CancelRequest request)
    {
        String reason = request == null ? null : request.reason();
        return Result.success(orderService.cancel(MemberContext.require(), orderNo, reason));
    }

    @PostMapping("/{orderNo}/confirm")
    public Result<ConfirmResponse> confirm(@PathVariable("orderNo") String orderNo)
    {
        return Result.success(orderService.confirm(MemberContext.require(), orderNo));
    }

    @PutMapping("/{orderNo}/address")
    public Result<Void> address(@PathVariable("orderNo") String orderNo, @Valid @RequestBody OrderAddressRequest request)
    {
        orderService.changeAddress(MemberContext.require(), orderNo, request.addressId());
        return Result.success();
    }
}
