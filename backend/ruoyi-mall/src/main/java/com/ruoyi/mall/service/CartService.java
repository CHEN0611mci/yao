package com.ruoyi.mall.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.domain.PetCartItem;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetMemberPet;
import com.ruoyi.mall.dto.CartAddRequest;
import com.ruoyi.mall.dto.CartUpdateRequest;
import com.ruoyi.mall.mapper.PetCartItemMapper;
import com.ruoyi.mall.mapper.PetItemMapper;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.mapper.PetMemberPetMapper;

/**
 * 购物车服务：加购合并、有效性校验与勾选结算。
 *
 * @author ruoyi
 */
@Service
public class CartService
{
    @Autowired
    private PetCartItemMapper cartMapper;

    @Autowired
    private PetItemMapper itemMapper;

    @Autowired
    private PetItemSkuMapper skuMapper;

    @Autowired
    private PetMemberPetMapper petMapper;

    @Autowired
    private MallConfigService configService;

    public List<PetCartItem> list(Long memberId)
    {
        return enrich(memberId, cartMapper.selectByMemberId(memberId), false);
    }

    public List<PetCartItem> checkedValidItems(Long memberId)
    {
        List<PetCartItem> enriched = enrich(memberId, cartMapper.selectChecked(memberId), true);
        List<PetCartItem> valid = new ArrayList<>();
        for (PetCartItem row : enriched)
        {
            if (Boolean.TRUE.equals(row.getValid()))
            {
                valid.add(row);
            }
        }
        return valid;
    }

    @Transactional(rollbackFor = Exception.class)
    public PetCartItem add(Long memberId, CartAddRequest request)
    {
        PetItemSku sku = skuMapper.selectById(request.skuId());
        if (sku == null || sku.getStatus() == null || sku.getStatus() != 1)
        {
            throw new BizException(ErrorCode.PET_3003, "SKU不存在或已下架");
        }
        PetItem item = itemMapper.selectSellableById(sku.getItemId());
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        verifyPet(memberId, request.petId());

        PetCartItem existing = cartMapper.selectByMemberAndSku(memberId, request.skuId());
        int quantity = request.quantity() + (existing == null ? 0 : existing.getQuantity());
        if (quantity > 99)
        {
            throw new BizException(ErrorCode.PET_3005, "单个SKU最多购买99件");
        }
        if (sku.getStock() == null || sku.getStock() < quantity)
        {
            throw new BizException(ErrorCode.PET_3001, "库存不足，当前仅剩"
                    + (sku.getStock() == null ? 0 : sku.getStock()) + "件");
        }
        if (existing == null)
        {
            if (cartMapper.countByMember(memberId) >= configService.cartMaxSku())
            {
                throw new BizException(ErrorCode.PET_1004,
                        "购物车最多保存" + configService.cartMaxSku() + "种商品");
            }
            PetCartItem row = new PetCartItem();
            row.setMemberId(memberId);
            row.setItemId(sku.getItemId());
            row.setSkuId(sku.getId());
            row.setQuantity(quantity);
            row.setChecked(1);
            row.setPetId(request.petId());
            cartMapper.insert(row);
            return cartMapper.selectByIdAndMember(row.getId(), memberId);
        }
        existing.setQuantity(quantity);
        if (request.petId() != null)
        {
            existing.setPetId(request.petId());
        }
        cartMapper.update(existing);
        return cartMapper.selectByIdAndMember(existing.getId(), memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetCartItem update(Long memberId, Long cartItemId, CartUpdateRequest request)
    {
        PetCartItem row = requireOwned(memberId, cartItemId);
        if (request.quantity() != null)
        {
            PetItemSku sku = skuMapper.selectById(row.getSkuId());
            if (sku == null || sku.getStatus() == null || sku.getStatus() != 1)
            {
                throw new BizException(ErrorCode.PET_3003, "SKU已下架");
            }
            if (sku.getStock() == null || sku.getStock() < request.quantity())
            {
                throw new BizException(ErrorCode.PET_3001,
                        "库存不足，当前仅剩" + (sku.getStock() == null ? 0 : sku.getStock()) + "件");
            }
            row.setQuantity(request.quantity());
        }
        if (request.checked() != null)
        {
            row.setChecked(request.checked() == 1 ? 1 : 0);
        }
        if (request.petId() != null)
        {
            verifyPet(memberId, request.petId());
            row.setPetId(request.petId());
        }
        cartMapper.update(row);
        return cartMapper.selectByIdAndMember(cartItemId, memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void remove(Long memberId, Long cartItemId)
    {
        requireOwned(memberId, cartItemId);
        cartMapper.delete(cartItemId, memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void clearChecked(Long memberId)
    {
        List<PetCartItem> checked = cartMapper.selectChecked(memberId);
        if (checked.isEmpty())
        {
            return;
        }
        List<Long> skuIds = new ArrayList<>();
        for (PetCartItem row : checked)
        {
            skuIds.add(row.getSkuId());
        }
        cartMapper.deleteByMemberAndSkus(memberId, skuIds);
    }

    public List<PetCartItem> enrich(Long memberId, List<PetCartItem> rows, boolean onlyValid)
    {
        Map<Long, String> petNames = new HashMap<>();
        for (PetMemberPet pet : petMapper.selectByMemberId(memberId, true))
        {
            petNames.put(pet.getId(), pet.getName());
        }
        List<PetCartItem> result = new ArrayList<>();
        for (PetCartItem row : rows)
        {
            PetItem item = itemMapper.selectSellableById(row.getItemId());
            PetItemSku sku = skuMapper.selectById(row.getSkuId());
            row.setItem(item);
            row.setSku(sku);
            row.setPetName(row.getPetId() == null ? null : petNames.get(row.getPetId()));

            String reason = null;
            if (item == null)
            {
                reason = "商品已下架";
            }
            else if (sku == null || sku.getStatus() == null || sku.getStatus() != 1)
            {
                reason = "规格已下架";
            }
            else if (!item.getId().equals(sku.getItemId()))
            {
                reason = "规格与商品不匹配";
            }
            else if (sku.getStock() == null || sku.getStock() < row.getQuantity())
            {
                reason = "库存不足";
            }
            row.setValid(reason == null);
            row.setInvalidReason(reason);
            if (sku != null && sku.getPrice() != null)
            {
                row.setAmount(PriceCalculator.money(
                        sku.getPrice().multiply(BigDecimal.valueOf(row.getQuantity()))));
            }
            if (!onlyValid || reason == null)
            {
                result.add(row);
            }
        }
        return result;
    }

    public PetCartItem requireOwned(Long memberId, Long cartItemId)
    {
        PetCartItem row = cartMapper.selectByIdAndMember(cartItemId, memberId);
        if (row == null)
        {
            throw new ForbiddenException("购物车记录不存在或无权访问");
        }
        return row;
    }

    private void verifyPet(Long memberId, Long petId)
    {
        if (petId == null)
        {
            return;
        }
        PetMemberPet pet = petMapper.selectByIdAndMember(petId, memberId);
        if (pet == null)
        {
            throw new ForbiddenException("宠物档案不存在或无权访问");
        }
    }
}
