package com.ruoyi.mall.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.domain.PetOrder;
import com.ruoyi.mall.domain.PetOrderItem;
import com.ruoyi.mall.dto.CancelResponse;
import com.ruoyi.mall.dto.ConfirmResponse;
import com.ruoyi.mall.dto.ShipRequest;
import com.ruoyi.mall.dto.ShipResponse;
import com.ruoyi.mall.mapper.PetOrderItemMapper;
import com.ruoyi.mall.mapper.PetOrderMapper;
import com.ruoyi.mall.mapper.PetPaymentMapper;
import com.ruoyi.mall.mapper.PetStockLogMapper;
import com.ruoyi.mall.state.OrderStateMachine;
import com.ruoyi.mall.state.OrderStatus;

/**
 * 订单服务：会员/商家/平台订单查询、取消、发货、收货与自动流转。
 *
 * @author ruoyi
 */
@Service
public class OrderService
{
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private PetOrderMapper orderMapper;

    @Autowired
    private PetOrderItemMapper orderItemMapper;

    @Autowired
    private PetPaymentMapper paymentMapper;

    @Autowired
    private PetStockLogMapper stockLogMapper;

    @Autowired
    private StockService stockService;

    @Autowired
    private OrderStateMachine stateMachine;

    @Autowired
    private MallConfigService configService;

    @Autowired
    private MessageService messageService;

    @Autowired private AddressService addressService;
    @Autowired private MemberWriteLock memberLock;
    @Autowired private PlatformTransactionManager transactionManager;

    public PageResult<PetOrder> memberList(Long memberId, Integer status, int pageNum, int pageSize)
    {
        return memberList(memberId, status, null, pageNum, pageSize);
    }

    public PageResult<PetOrder> memberList(Long memberId, Integer status, String keyword, int pageNum, int pageSize)
    {
        PageHelper.startPage(pageNum, pageSize);
        List<PetOrder> orders = orderMapper.selectMemberOrders(memberId, status, StringUtils.trim(keyword));
        PageInfo<PetOrder> pageInfo = new PageInfo<>(orders);
        attachItems(pageInfo.getList());
        return PageResult.of(pageInfo);
    }

    @Transactional(rollbackFor = Exception.class)
    public void changeAddress(Long memberId, String orderNo, Long addressId)
    {
        memberLock.acquire(memberId);
        PetOrder order = orderMapper.selectByOrderNoAndMember(orderNo, memberId);
        if (order == null) throw new BizException(ErrorCode.PET_4003);
        var address = addressService.getOwned(memberId, addressId);
        JSONObject snapshot = JSON.parseObject(JSON.toJSONString(address));
        snapshot.put("addressId", address.getId());
        if (orderMapper.changeAddress(orderNo, memberId, snapshot.toJSONString()) != 1)
            throw new BizException(ErrorCode.PET_3002, "订单已发货或已关闭，无法修改地址");
        messageService.notify(memberId, "ORDER", "订单收货地址已修改", "订单" + orderNo + "已更新收货地址。", "/orders/" + orderNo);
    }

    public PetOrder memberDetail(Long memberId, String orderNo)
    {
        PetOrder order = orderMapper.selectByOrderNoAndMember(orderNo, memberId);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        fillDetail(order, true);
        return order;
    }

    public PageResult<PetOrder> merchantList(Long merchantId, Integer status, String orderNo,
            int pageNum, int pageSize)
    {
        Map<String, Object> query = new HashMap<>();
        query.put("merchantId", merchantId);
        query.put("status", status);
        query.put("orderNo", StringUtils.trim(orderNo));
        PageHelper.startPage(pageNum, pageSize);
        PageInfo<PetOrder> pageInfo = new PageInfo<>(orderMapper.selectMerchantOrders(query));
        attachItems(pageInfo.getList());
        return PageResult.of(pageInfo);
    }

    public PetOrder merchantDetail(Long merchantId, String orderNo)
    {
        PetOrder order = orderMapper.selectByOrderNo(orderNo);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        if (!merchantId.equals(order.getMerchantId()))
        {
            throw new ForbiddenException("无权查看该订单");
        }
        fillDetail(order, true);
        return order;
    }

    public PageResult<PetOrder> adminList(String orderNo, Long memberId, Long merchantId,
            Integer status, String startTime, String endTime, int pageNum, int pageSize)
    {
        Map<String, Object> query = new LinkedHashMap<>();
        query.put("orderNo", StringUtils.trim(orderNo));
        query.put("memberId", memberId);
        query.put("merchantId", merchantId);
        query.put("status", status);
        query.put("startTime", StringUtils.trim(startTime));
        query.put("endTime", StringUtils.trim(endTime));
        PageHelper.startPage(pageNum, pageSize);
        PageInfo<PetOrder> pageInfo = new PageInfo<>(orderMapper.selectAdminOrders(query));
        attachItems(pageInfo.getList());
        return PageResult.of(pageInfo);
    }

    public PetOrder adminDetail(String orderNo)
    {
        PetOrder order = orderMapper.selectByOrderNo(orderNo);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        fillDetail(order, true);
        return order;
    }

    @Transactional(rollbackFor = Exception.class)
    public CancelResponse cancel(Long memberId, String orderNo, String reason)
    {
        PetOrder order = orderMapper.selectByOrderNoAndMember(orderNo, memberId);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        stateMachine.assertTransition(order.getStatus(), OrderStatus.CANCELLED.getCode());
        String finalReason = StringUtils.isEmpty(reason) ? "用户主动取消" : reason.trim();
        if (finalReason.length() > 200)
        {
            finalReason = finalReason.substring(0, 200);
        }
        // Use the exact PK. A member/status range can hold gap locks that block
        // new orders while this transaction waits to restore SKU stock.
        int rows = orderMapper.cancel(order.getId(), memberId, finalReason);
        if (rows == 0)
        {
            throw new BizException(ErrorCode.PET_3002, "订单状态已变化，请刷新后重试");
        }
        rollbackStock(order, "会员取消订单", "member:" + memberId);
        messageService.notify(memberId, "ORDER", "订单已取消",
                "订单" + orderNo + "已取消，库存已释放。", "/pages/order/detail?orderNo=" + orderNo);
        return new CancelResponse(orderNo, OrderStatus.CANCELLED.getCode(), true);
    }

    @Transactional(rollbackFor = Exception.class)
    public ShipResponse ship(Long merchantId, String orderNo, ShipRequest request)
    {
        PetOrder order = orderMapper.selectByOrderNo(orderNo);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        if (!merchantId.equals(order.getMerchantId()))
        {
            throw new ForbiddenException("无权操作该订单");
        }
        if (alreadyShipped(order, request)) return new ShipResponse(orderNo, order.getStatus(), order.getShipTime(), request.company(), request.trackingNo());
        stateMachine.assertTransition(order.getStatus(), OrderStatus.PENDING_RECEIPT.getCode());
        String snapshot = appendLogistics(order.getReceiverSnapshot(), request.company(), request.trackingNo());
        int rows = orderMapper.updateShipInfo(orderNo, merchantId, snapshot);
        if (rows == 0)
        {
            throw new BizException(ErrorCode.PET_3002, "订单状态已变化，请刷新后重试");
        }
        messageService.notify(order.getMemberId(), "ORDER", "订单已发货",
                "订单" + orderNo + "已由" + request.company() + "发出，运单号" + request.trackingNo() + "。",
                "/pages/order/detail?orderNo=" + orderNo);
        return new ShipResponse(orderNo, OrderStatus.PENDING_RECEIPT.getCode(), new Date(),
                request.company(), request.trackingNo());
    }

    /**
     * 平台代发货：跳过商家归属校验，其余流程与商家发货一致。
     */
    @Transactional(rollbackFor = Exception.class)
    public ShipResponse adminShip(String orderNo, ShipRequest request, String operator)
    {
        PetOrder order = orderMapper.selectByOrderNo(orderNo);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        if (alreadyShipped(order, request)) return new ShipResponse(orderNo, order.getStatus(), order.getShipTime(), request.company(), request.trackingNo());
        stateMachine.assertTransition(order.getStatus(), OrderStatus.PENDING_RECEIPT.getCode());
        String snapshot = appendLogistics(order.getReceiverSnapshot(), request.company(), request.trackingNo());
        int rows = orderMapper.updateShipInfo(orderNo, null, snapshot);
        if (rows == 0)
        {
            throw new BizException(ErrorCode.PET_3002, "订单状态已变化，请刷新后重试");
        }
        messageService.notify(order.getMemberId(), "ORDER", "订单已发货",
                "订单" + orderNo + "已由" + request.company() + "发出，运单号" + request.trackingNo() + "。",
                "/pages/order/detail?orderNo=" + orderNo);
        return new ShipResponse(orderNo, OrderStatus.PENDING_RECEIPT.getCode(), new Date(),
                request.company(), request.trackingNo());
    }

    @Transactional(rollbackFor = Exception.class)
    public ConfirmResponse confirm(Long memberId, String orderNo)
    {
        PetOrder order = orderMapper.selectByOrderNoAndMember(orderNo, memberId);
        if (order == null)
        {
            throw new BizException(ErrorCode.PET_4003);
        }
        stateMachine.assertTransition(order.getStatus(), OrderStatus.COMPLETED.getCode());
        int rows = orderMapper.confirm(orderNo, memberId);
        if (rows == 0)
        {
            throw new BizException(ErrorCode.PET_3002, "订单状态已变化，请刷新后重试");
        }
        messageService.notify(memberId, "ORDER", "订单已完成", "订单" + orderNo + "已确认收货。", "/orders/" + orderNo);
        return new ConfirmResponse(orderNo, OrderStatus.COMPLETED.getCode(), new Date());
    }

    /**
     * 超时未支付关单，逐个订单回滚预占库存。
     */
    public int closeTimeoutOrders()
    {
        int closed = 0;
        List<PetOrder> orders = orderMapper.selectTimeoutOrders(100);
        // Release SKU locks after each order. A batch-wide transaction can hold a
        // higher SKU from one order while waiting for a lower SKU in the next.
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        for (PetOrder order : orders)
        {
            Boolean changed = transaction.execute(status -> {
                if (orderMapper.close(order.getId(), "支付超时自动关闭") == 0) return false;
                rollbackStock(order, "支付超时关单", "system:timeout");
                messageService.notify(order.getMemberId(), "ORDER", "订单已关闭",
                        "订单" + order.getOrderNo() + "因超时未支付已自动关闭。",
                        "/pages/order/detail?orderNo=" + order.getOrderNo());
                return true;
            });
            if (Boolean.TRUE.equals(changed)) closed++;
        }
        return closed;
    }

    /**
     * 发货后超过配置天数自动确认收货。
     */
    @Transactional(rollbackFor = Exception.class)
    public int autoConfirmOrders()
    {
        int confirmed = 0;
        List<PetOrder> orders = orderMapper.selectAutoConfirmOrders(configService.autoConfirmDays(), 100);
        for (PetOrder order : orders)
        {
            if (orderMapper.confirm(order.getOrderNo(), order.getMemberId()) > 0)
            {
                messageService.notify(order.getMemberId(), "ORDER", "订单已自动确认收货",
                        "订单" + order.getOrderNo() + "已达到自动确认收货时限。", "/orders/" + order.getOrderNo());
                confirmed++;
            }
        }
        return confirmed;
    }

    private void fillDetail(PetOrder order, boolean withStockLogs)
    {
        order.setStatusText(OrderStatus.labelOf(order.getStatus()));
        order.setItems(orderItemMapper.selectByOrderId(order.getId()));
        order.setPayment(paymentMapper.selectByOrderNo(order.getOrderNo()));
        if (withStockLogs)
        {
            Map<String, Object> query = new HashMap<>();
            query.put("orderNo", order.getOrderNo());
            order.setStockLogs(stockLogMapper.selectList(query));
        }
    }

    private void attachItems(List<PetOrder> orders)
    {
        if (orders == null || orders.isEmpty())
        {
            return;
        }
        List<Long> ids = new ArrayList<>();
        for (PetOrder order : orders)
        {
            order.setStatusText(OrderStatus.labelOf(order.getStatus()));
            ids.add(order.getId());
        }
        List<PetOrderItem> items = orderItemMapper.selectByOrderIds(ids);
        Map<Long, List<PetOrderItem>> grouped = new HashMap<>();
        for (PetOrderItem item : items)
        {
            grouped.computeIfAbsent(item.getOrderId(), key -> new ArrayList<>()).add(item);
        }
        for (PetOrder order : orders)
        {
            order.setItems(grouped.getOrDefault(order.getId(), new ArrayList<>()));
        }
    }

    private void rollbackStock(PetOrder order, String remark, String operator)
    {
        List<PetOrderItem> items = orderItemMapper.selectByOrderId(order.getId());
        // Match checkout's SKU order, including historical orders whose lines were reversed.
        items.sort(java.util.Comparator.comparing(PetOrderItem::getSkuId));
        for (PetOrderItem item : items)
        {
            stockService.rollback(item.getSkuId(), item.getQuantity(), order.getOrderNo(),
                    operator, remark);
        }
    }

    private boolean alreadyShipped(PetOrder order, ShipRequest request)
    {
        if (order.getStatus() != 3 && order.getStatus() != 4) return false;
        JSONObject data = JSON.parseObject(order.getReceiverSnapshot());
        JSONObject logistics = data == null ? null : data.getJSONObject("logistics");
        return logistics != null && request.company().equals(logistics.getString("company"))
                && request.trackingNo().equals(logistics.getString("trackingNo"));
    }

    private String appendLogistics(String snapshot, String company, String trackingNo)
    {
        JSONObject data = StringUtils.isEmpty(snapshot) ? new JSONObject() : JSON.parseObject(snapshot);
        if (data == null)
        {
            data = new JSONObject();
            if (StringUtils.isNotEmpty(snapshot))
            {
                data.put("raw", snapshot);
            }
        }
        JSONObject logistics = new JSONObject();
        logistics.put("company", company);
        logistics.put("trackingNo", trackingNo);
        logistics.put("shipTime", LocalDateTime.now().format(TIME_FORMAT));
        data.put("logistics", logistics);
        return data.toJSONString();
    }
}

