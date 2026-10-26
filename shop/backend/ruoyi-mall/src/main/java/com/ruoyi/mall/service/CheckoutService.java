package com.ruoyi.mall.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.DuplicateRequestException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.domain.PetAddress;
import com.ruoyi.mall.domain.PetCartItem;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetMemberPet;
import com.ruoyi.mall.domain.PetOrder;
import com.ruoyi.mall.domain.PetOrderItem;
import com.ruoyi.mall.dto.CheckoutPreviewRequest;
import com.ruoyi.mall.dto.OrderLineRequest;
import com.ruoyi.mall.dto.OrderSubmitResponse;
import com.ruoyi.mall.dto.PreviewItem;
import com.ruoyi.mall.dto.PreviewResponse;
import com.ruoyi.mall.dto.SubmitOrderRequest;
import com.ruoyi.mall.mapper.PetCartItemMapper;
import com.ruoyi.mall.mapper.PetItemMapper;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.mapper.PetMemberPetMapper;
import com.ruoyi.mall.mapper.PetOrderItemMapper;
import com.ruoyi.mall.mapper.PetOrderMapper;

/**
 * 结算服务：试算、幂等下单、库存预占与地址快照。
 *
 * @author ruoyi
 */
@Service
public class CheckoutService
{
    private static final DateTimeFormatter ORDER_NO_FORMAT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    @Autowired
    private PetOrderMapper orderMapper;

    @Autowired
    private PetOrderItemMapper orderItemMapper;

    @Autowired
    private PetCartItemMapper cartMapper;

    @Autowired
    private PetItemMapper itemMapper;

    @Autowired
    private PetItemSkuMapper skuMapper;

    @Autowired
    private PetMemberPetMapper petMapper;

    @Autowired
    private AddressService addressService;

    @Autowired
    private StockService stockService;

    @Autowired
    private PriceCalculator priceCalculator;

    @Autowired
    private MallConfigService configService;

    @Autowired
    private MessageService messageService;

    public PreviewResponse preview(Long memberId, CheckoutPreviewRequest request)
    {
        List<String> warnings = new ArrayList<>();
        List<CheckoutLine> lines = request != null && request.skuIds() != null && !request.skuIds().isEmpty()
                ? linesFromCart(memberId, new LinkedHashSet<>(request.skuIds()), warnings)
                : linesFromCart(memberId, null, warnings);
        if (lines.isEmpty())
        {
            throw new BizException(ErrorCode.PET_1001, "请选择要结算的商品");
        }
        PriceCalculator.CalcResult calc = priceCalculator.calculate(toPriceLines(lines),
                configService.freightFreeThreshold(), configService.freightFee());
        List<PreviewItem> items = new ArrayList<>();
        for (CheckoutLine line : lines)
        {
            items.add(toPreviewItem(line));
        }
        return new PreviewResponse(items, calc.totalAmount(), calc.discountAmount(), calc.freight(),
                calc.payAmount(), calc.freeShipping(), warnings);
    }

    @Transactional(rollbackFor = Exception.class)
    public OrderSubmitResponse submit(Long memberId, SubmitOrderRequest request)
    {
        String clientToken = request.clientToken().trim();
        PetOrder existing = orderMapper.selectByClientToken(memberId, clientToken);
        if (existing != null)
        {
            throw new DuplicateRequestException(toSubmitResponse(existing, true));
        }
        PetAddress address = addressService.getOwned(memberId, request.addressId());

        List<String> warnings = new ArrayList<>();
        List<CheckoutLine> lines = linesFromSubmit(memberId, request.items(), warnings);
        if (lines.isEmpty())
        {
            throw new BizException(ErrorCode.PET_1001, "订单明细不能为空");
        }
        Long merchantId = lines.get(0).item().getMerchantId();
        for (CheckoutLine line : lines)
        {
            if (!merchantId.equals(line.item().getMerchantId()))
            {
                throw new BizException(ErrorCode.PET_1001, "仅支持同一店铺的商品一起结算");
            }
        }

        PriceCalculator.CalcResult calc = priceCalculator.calculate(toPriceLines(lines),
                configService.freightFreeThreshold(), configService.freightFee());
        String orderNo = nextOrderNo();
        Date expireAt = new Date(System.currentTimeMillis()
                + configService.payTimeoutMinutes() * 60_000L);

        PetOrder order = new PetOrder();
        order.setOrderNo(orderNo);
        order.setMemberId(memberId);
        order.setMerchantId(merchantId);
        order.setTotalAmount(calc.totalAmount());
        order.setDiscountAmount(calc.discountAmount());
        order.setFreight(calc.freight());
        order.setPayAmount(calc.payAmount());
        order.setStatus(0);
        order.setReceiverSnapshot(receiverSnapshot(address));
        order.setPetSnapshot(petSnapshot(lines));
        order.setRemark(request.remark());
        order.setClientToken(clientToken);
        order.setExpireAt(expireAt);
        orderMapper.insert(order);

        List<PetOrderItem> orderItems = new ArrayList<>();
        for (CheckoutLine line : lines)
        {
            PetOrderItem item = new PetOrderItem();
            item.setOrderId(order.getId());
            item.setItemId(line.item().getId());
            item.setSkuId(line.sku().getId());
            item.setTitle(line.item().getTitle());
            item.setSpec(line.sku().getSpecName());
            item.setPrice(line.sku().getPrice());
            item.setQuantity(line.quantity());
            item.setAmount(PriceCalculator.money(
                    line.sku().getPrice().multiply(BigDecimal.valueOf(line.quantity()))));
            item.setImage(line.sku().getImage() == null ? line.item().getMainImage() : line.sku().getImage());
            item.setPetSnapshot(line.petName());
            orderItems.add(item);
        }
        orderItemMapper.batchInsert(orderItems);

        Set<Long> skuIds = new LinkedHashSet<>();
        for (CheckoutLine line : lines)
        {
            skuIds.add(line.sku().getId());
            stockService.deduct(line.sku().getId(), line.quantity(), orderNo,
                    "member:" + memberId, "下单预占库存");
            itemMapper.incrementSales(line.item().getId(), line.quantity());
        }
        cartMapper.deleteByMemberAndSkus(memberId, new ArrayList<>(skuIds));

        messageService.notify(memberId, "ORDER", "下单成功",
                "订单" + orderNo + "已创建，请在" + configService.payTimeoutMinutes() + "分钟内完成支付。",
                "/pages/order/detail?orderNo=" + orderNo);
        return new OrderSubmitResponse(orderNo, order.getPayAmount(), order.getFreight(),
                order.getStatus(), expireAt, false);
    }

    private List<CheckoutLine> linesFromCart(Long memberId, Set<Long> onlySkuIds, List<String> warnings)
    {
        List<PetCartItem> rows = cartMapper.selectByMemberId(memberId);
        List<CheckoutLine> lines = new ArrayList<>();
        Set<Long> found = new LinkedHashSet<>();
        for (PetCartItem row : rows)
        {
            if (onlySkuIds == null)
            {
                if (row.getChecked() == null || row.getChecked() != 1)
                {
                    continue;
                }
            }
            else if (!onlySkuIds.contains(row.getSkuId()))
            {
                continue;
            }
            found.add(row.getSkuId());
            CheckoutLine line = buildLine(memberId, row.getSkuId(), row.getQuantity(),
                    row.getPetId(), warnings, false);
            if (line != null)
            {
                lines.add(line);
            }
        }
        if (onlySkuIds != null && !onlySkuIds.isEmpty() && found.size() < onlySkuIds.size())
        {
            warnings.add("部分商品已失效或不在购物车中");
        }
        return lines;
    }

    private List<CheckoutLine> linesFromSubmit(Long memberId, List<OrderLineRequest> requests,
            List<String> warnings)
    {
        Map<Long, OrderLineRequest> merged = new LinkedHashMap<>();
        for (OrderLineRequest request : requests)
        {
            OrderLineRequest old = merged.get(request.skuId());
            if (old == null)
            {
                merged.put(request.skuId(), request);
            }
            else
            {
                int quantity = old.quantity() + request.quantity();
                if (quantity > 99)
                {
                    throw new BizException(ErrorCode.PET_3005, "单个SKU最多购买99件");
                }
                merged.put(request.skuId(), new OrderLineRequest(request.skuId(), quantity,
                        old.petId() == null ? request.petId() : old.petId()));
            }
        }
        List<CheckoutLine> lines = new ArrayList<>();
        for (OrderLineRequest request : merged.values())
        {
            CheckoutLine line = buildLine(memberId, request.skuId(), request.quantity(),
                    request.petId(), warnings, true);
            if (line != null)
            {
                lines.add(line);
            }
        }
        return lines;
    }

    private CheckoutLine buildLine(Long memberId, Long skuId, Integer quantity, Long petId,
            List<String> warnings, boolean strict)
    {
        PetItemSku sku = skuMapper.selectById(skuId);
        if (sku == null || sku.getStatus() == null || sku.getStatus() != 1)
        {
            if (strict)
            {
                throw new BizException(ErrorCode.PET_3003, "SKU不存在或已下架");
            }
            warnings.add("SKU[" + skuId + "]已失效");
            return null;
        }
        PetItem item = itemMapper.selectSellableById(sku.getItemId());
        if (item == null)
        {
            if (strict)
            {
                throw new BizException(ErrorCode.PET_3003, "商品已下架");
            }
            warnings.add("商品[" + sku.getItemId() + "]已下架");
            return null;
        }
        int qty = quantity == null ? 0 : quantity;
        if (qty < 1 || qty > 99)
        {
            if (strict)
            {
                throw new BizException(ErrorCode.PET_3005, "购买数量需在1-99之间");
            }
            warnings.add(item.getTitle() + " 购买数量不合法");
            return null;
        }
        if (sku.getStock() == null || sku.getStock() < qty)
        {
            warnings.add(item.getTitle() + " 库存不足，当前仅剩"
                    + (sku.getStock() == null ? 0 : sku.getStock()) + "件");
            if (strict)
            {
                throw new BizException(ErrorCode.PET_3001, item.getTitle() + " 库存不足");
            }
        }
        String petName = null;
        if (petId != null)
        {
            PetMemberPet pet = petMapper.selectByIdAndMember(petId, memberId);
            if (pet == null)
            {
                if (strict)
                {
                    throw new BizException(ErrorCode.PET_1001, "宠物档案不存在或无权访问");
                }
                warnings.add("关联的宠物档案已不存在");
            }
            else
            {
                petName = pet.getName();
            }
        }
        return new CheckoutLine(sku, item, qty, petId, petName);
    }

    private List<PriceCalculator.Line> toPriceLines(List<CheckoutLine> lines)
    {
        List<PriceCalculator.Line> result = new ArrayList<>();
        for (CheckoutLine line : lines)
        {
            result.add(new PriceCalculator.Line(line.sku().getPrice(), line.quantity()));
        }
        return result;
    }

    private PreviewItem toPreviewItem(CheckoutLine line)
    {
        return new PreviewItem(line.sku().getId(), line.item().getId(), line.item().getTitle(),
                line.sku().getSpecName(), line.sku().getPrice(), line.quantity(),
                PriceCalculator.money(line.sku().getPrice().multiply(BigDecimal.valueOf(line.quantity()))),
                line.petName(),
                line.sku().getImage() == null ? line.item().getMainImage() : line.sku().getImage());
    }

    private OrderSubmitResponse toSubmitResponse(PetOrder order, boolean duplicated)
    {
        return new OrderSubmitResponse(order.getOrderNo(), order.getPayAmount(), order.getFreight(),
                order.getStatus(), order.getExpireAt(), duplicated);
    }

    private String receiverSnapshot(PetAddress address)
    {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("id", address.getId());
        snapshot.put("receiver", address.getReceiver());
        snapshot.put("phone", address.getPhone());
        snapshot.put("province", address.getProvince());
        snapshot.put("city", address.getCity());
        snapshot.put("district", address.getDistrict());
        snapshot.put("detail", address.getDetail());
        return JSON.toJSONString(snapshot);
    }

    private String petSnapshot(List<CheckoutLine> lines)
    {
        Set<String> names = new LinkedHashSet<>();
        for (CheckoutLine line : lines)
        {
            if (line.petName() != null)
            {
                names.add(line.petName());
            }
        }
        return names.isEmpty() ? null : String.join("、", names);
    }

    private String nextOrderNo()
    {
        return "PM" + LocalDateTime.now().format(ORDER_NO_FORMAT)
                + String.format("%06d", ThreadLocalRandom.current().nextInt(1_000_000));
    }

    private record CheckoutLine(PetItemSku sku, PetItem item, int quantity, Long petId, String petName)
    {
    }
}


