package com.ruoyi.mall.service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.Period;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.domain.PetItem;
import com.ruoyi.mall.domain.PetItemAudit;
import com.ruoyi.mall.domain.PetItemImage;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetMemberPet;
import com.ruoyi.mall.dto.AdaptResult;
import com.ruoyi.mall.dto.AuditRequest;
import com.ruoyi.mall.dto.AuditResponse;
import com.ruoyi.mall.dto.ImageRequest;
import com.ruoyi.mall.dto.ItemQuery;
import com.ruoyi.mall.dto.ItemSaveRequest;
import com.ruoyi.mall.dto.SkuRequest;
import com.ruoyi.mall.mapper.PetCategoryMapper;
import com.ruoyi.mall.mapper.PetItemAuditMapper;
import com.ruoyi.mall.mapper.PetItemImageMapper;
import com.ruoyi.mall.mapper.PetItemMapper;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.mapper.PetMemberPetMapper;

/**
 * 商品服务：前台检索、详情、宠物适配与后台发布/审核。
 *
 * @author ruoyi
 */
@Service
public class ItemService
{
    private static final Pattern RANGE_PATTERN =
            Pattern.compile("(\\d+(?:\\.\\d+)?)\\s*[-~至]\\s*(\\d+(?:\\.\\d+)?)");

    @Autowired
    private PetItemMapper itemMapper;

    @Autowired
    private PetItemSkuMapper skuMapper;

    @Autowired
    private PetItemImageMapper imageMapper;

    @Autowired
    private PetItemAuditMapper auditMapper;

    @Autowired
    private PetCategoryMapper categoryMapper;

    @Autowired
    private PetMemberPetMapper petMapper;

    @Autowired
    private CategoryService categoryService;

    public PageResult<PetItem> publicList(ItemQuery query, Long memberId)
    {
        PageHelper.startPage(query.safePageNum(), query.safePageSize());
        List<PetItem> list = itemMapper.selectPublicList(publicQuery(query));
        PageInfo<PetItem> pageInfo = new PageInfo<>(list);
        applyAdapt(pageInfo.getList(), memberId);
        return PageResult.of(pageInfo);
    }

    public List<PetItem> recommend(int limit, Long memberId)
    {
        List<PetItem> list = itemMapper.selectRecommend(Math.max(1, Math.min(limit, 20)));
        applyAdapt(list, memberId);
        return list;
    }

    public PetItem publicDetail(Long itemId, Long memberId)
    {
        PetItem item = itemMapper.selectSellableById(itemId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        fillDetail(item, true);
        applyAdapt(java.util.Collections.singletonList(item), memberId);
        return item;
    }

    public PetItem merchantDetail(Long itemId, Long merchantId)
    {
        PetItem item = requireOwned(itemId, merchantId);
        fillDetail(item, false);
        return item;
    }

    public PetItem adminDetail(Long itemId)
    {
        PetItem item = itemMapper.selectById(itemId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        fillDetail(item, false);
        item.setAudits(auditMapper.selectByItemId(itemId));
        return item;
    }

    public PageResult<PetItem> adminList(ItemQuery query)
    {
        PageHelper.startPage(query.safePageNum(), query.safePageSize());
        Map<String, Object> params = adminQuery(query, null);
        PageInfo<PetItem> pageInfo = new PageInfo<>(itemMapper.selectAdminList(params));
        return PageResult.of(pageInfo);
    }

    public PageResult<PetItem> merchantList(ItemQuery query, Long merchantId)
    {
        PageHelper.startPage(query.safePageNum(), query.safePageSize());
        PageInfo<PetItem> pageInfo = new PageInfo<>(
                itemMapper.selectAdminList(adminQuery(query, merchantId)));
        return PageResult.of(pageInfo);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetItem create(ItemSaveRequest request, Long merchantId, boolean admin)
    {
        Long ownerId = admin ? request.merchantId() : merchantId;
        if (ownerId == null)
        {
            throw new BizException(ErrorCode.PET_1001, "商户不能为空");
        }
        if (categoryMapper.selectById(request.categoryId()) == null)
        {
            throw new BizException(ErrorCode.PET_1001, "分类不存在");
        }
        List<SkuRequest> skus = requireSkus(request.skus());

        PetItem item = new PetItem();
        item.setMerchantId(ownerId);
        item.setAuditStatus(admin ? 2 : 0);
        item.setStatus(0);
        applyItem(item, request);
        item.setPriceMin(minPrice(skus));
        itemMapper.insert(item);

        saveSkus(item.getId(), skus);
        saveImages(item.getId(), request.images(), request.mainImage());
        return adminDetail(item.getId());
    }

    @Transactional(rollbackFor = Exception.class)
    public PetItem update(Long itemId, ItemSaveRequest request, Long merchantId, boolean admin)
    {
        PetItem item = admin ? itemMapper.selectById(itemId) : requireOwned(itemId, merchantId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        if (categoryMapper.selectById(request.categoryId()) == null)
        {
            throw new BizException(ErrorCode.PET_1001, "分类不存在");
        }
        if (admin && request.merchantId() != null)
        {
            item.setMerchantId(request.merchantId());
        }
        applyItem(item, request);
        if (!admin)
        {
            item.setAuditStatus(0);
            item.setStatus(0);
        }
        if (request.skus() != null && !request.skus().isEmpty())
        {
            upsertSkus(itemId, request.skus());
            item.setPriceMin(minPriceOfEnabled(itemId));
        }
        itemMapper.update(item);
        if (request.images() != null)
        {
            imageMapper.deleteByItemId(itemId);
            saveImages(itemId, request.images(), request.mainImage());
        }
        return admin ? adminDetail(itemId) : merchantDetail(itemId, merchantId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(Long itemId, Integer status, Long merchantId, boolean admin)
    {
        PetItem item = admin ? itemMapper.selectById(itemId) : requireOwned(itemId, merchantId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        if (status == 1 && (item.getAuditStatus() == null || item.getAuditStatus() != 2))
        {
            throw new BizException(ErrorCode.PET_3003, "商品未审核通过，不能上架");
        }
        itemMapper.updateStatus(itemId, status);
    }

    @Transactional(rollbackFor = Exception.class)
    public AuditResponse audit(Long itemId, AuditRequest request, String auditor)
    {
        PetItem item = itemMapper.selectById(itemId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        if (request.auditStatus() == 1 && StringUtils.isEmpty(request.remark()))
        {
            throw new BizException(ErrorCode.PET_1001, "驳回时必须填写审核意见");
        }
        itemMapper.updateAudit(itemId, request.auditStatus());

        PetItemAudit audit = new PetItemAudit();
        audit.setItemId(itemId);
        audit.setAuditStatus(request.auditStatus());
        audit.setAuditor(auditor);
        audit.setRemark(request.remark());
        auditMapper.insert(audit);
        return new AuditResponse(itemId, request.auditStatus());
    }

    /**
     * 对商品列表批量计算宠物适配度，避免逐条查询宠物档案。
     */
    private void applyAdapt(List<PetItem> items, Long memberId)
    {
        if (items == null || items.isEmpty() || memberId == null)
        {
            return;
        }
        List<PetMemberPet> pets = petMapper.selectByMemberId(memberId, false);
        if (pets.isEmpty())
        {
            return;
        }
        for (PetItem item : items)
        {
            List<AdaptResult> results = new ArrayList<>();
            for (PetMemberPet pet : pets)
            {
                results.add(evaluate(item, pet));
            }
            item.setAdapts(results);
            item.setAdapt(highest(results));
        }
    }

    private AdaptResult evaluate(PetItem item, PetMemberPet pet)
    {
        List<String> reasons = new ArrayList<>();
        String level = "SUITABLE";
        String species = item.getPetSpecies() == null ? "ALL" : item.getPetSpecies();
        if (!"ALL".equals(species) && !species.equals(pet.getSpecies()))
        {
            level = "UNSUITABLE";
            reasons.add("该商品适用物种为" + speciesLabel(species));
        }
        String stage = ageStageOf(pet.getBirthday());
        if (stage != null && item.getAgeStage() != null && !"ALL".equals(item.getAgeStage())
                && !stage.equals(item.getAgeStage()))
        {
            if (!"UNSUITABLE".equals(level))
            {
                level = "CAUTION";
            }
            reasons.add("适用年龄段为" + ageLabel(item.getAgeStage()));
        }
        if (stage == null)
        {
            if ("SUITABLE".equals(level))
            {
                level = "CAUTION";
            }
            reasons.add("宠物生日未完善，无法判断适用年龄");
        }
        if (pet.getWeight() != null && StringUtils.isNotEmpty(item.getWeightRange()))
        {
            BigDecimal[] range = parseRange(item.getWeightRange());
            if (range != null && (pet.getWeight().compareTo(range[0]) < 0
                    || pet.getWeight().compareTo(range[1]) > 0))
            {
                if (!"UNSUITABLE".equals(level))
                {
                    level = "CAUTION";
                }
                reasons.add("适用体重范围为" + item.getWeightRange() + "kg");
            }
        }
        if (StringUtils.isNotEmpty(pet.getAllergyNote()))
        {
            String allergy = pet.getAllergyNote().toLowerCase();
            String text = (StringUtils.nvl(item.getTitle(), "") + " "
                    + StringUtils.nvl(item.getSubtitle(), "") + " "
                    + StringUtils.nvl(item.getDetail(), "")).toLowerCase();
            for (String token : allergy.split("[,，、;；\\s]+"))
            {
                if (token.length() >= 2 && text.contains(token))
                {
                    if (!"UNSUITABLE".equals(level))
                    {
                        level = "CAUTION";
                    }
                    reasons.add("配方可能含有过敏原：" + token);
                    break;
                }
            }
        }
        if (reasons.isEmpty())
        {
            reasons.add("物种、年龄与体重均匹配");
        }
        return new AdaptResult(level, pet.getId(), pet.getName(), reasons);
    }

    private AdaptResult highest(List<AdaptResult> results)
    {
        AdaptResult selected = results.get(0);
        for (AdaptResult result : results)
        {
            if (severity(result.level()) > severity(selected.level()))
            {
                selected = result;
            }
        }
        return selected;
    }

    private int severity(String level)
    {
        switch (level)
        {
            case "UNSUITABLE":
                return 3;
            case "CAUTION":
                return 2;
            case "SUITABLE":
                return 1;
            default:
                return 0;
        }
    }

    private String ageStageOf(Date birthday)
    {
        if (birthday == null)
        {
            return null;
        }
        LocalDate birth = birthday.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        long months = Period.between(birth, LocalDate.now()).toTotalMonths();
        if (months <= 12)
        {
            return "JUNIOR";
        }
        if (months <= 84)
        {
            return "ADULT";
        }
        return "SENIOR";
    }

    private BigDecimal[] parseRange(String text)
    {
        Matcher matcher = RANGE_PATTERN.matcher(text);
        if (!matcher.find())
        {
            return null;
        }
        return new BigDecimal[] { new BigDecimal(matcher.group(1)), new BigDecimal(matcher.group(2)) };
    }

    private String speciesLabel(String species)
    {
        switch (species)
        {
            case "CAT":
                return "猫";
            case "DOG":
                return "狗";
            case "SMALL":
                return "小宠";
            default:
                return "通用";
        }
    }

    private String ageLabel(String stage)
    {
        switch (stage)
        {
            case "JUNIOR":
                return "幼年";
            case "ADULT":
                return "成年";
            case "SENIOR":
                return "老年";
            default:
                return "全年龄";
        }
    }

    private void fillDetail(PetItem item, boolean onlyEnabled)
    {
        item.setSkus(skuMapper.selectByItemId(item.getId(), onlyEnabled));
        item.setImages(imageMapper.selectByItemId(item.getId()));
    }

    private PetItem requireOwned(Long itemId, Long merchantId)
    {
        PetItem item = itemMapper.selectById(itemId);
        if (item == null)
        {
            throw new BizException(ErrorCode.PET_3003);
        }
        if (!item.getMerchantId().equals(merchantId))
        {
            throw new ForbiddenException("无权操作该商品");
        }
        return item;
    }

    private void applyItem(PetItem item, ItemSaveRequest request)
    {
        item.setCategoryId(request.categoryId());
        item.setTitle(request.title().trim());
        item.setSubtitle(request.subtitle());
        item.setMainImage(request.mainImage());
        item.setBrand(request.brand());
        item.setPetSpecies(request.petSpecies());
        item.setAgeStage(request.ageStage());
        item.setWeightRange(request.weightRange());
        item.setCostPrice(request.costPrice());
        item.setSupportSubscribe(request.supportSubscribe() == null ? 0 : request.supportSubscribe());
        item.setIsPrescription(request.isPrescription() == null ? 0 : request.isPrescription());
        item.setDetail(request.detail());
    }

    private List<SkuRequest> requireSkus(List<SkuRequest> skus)
    {
        if (skus == null || skus.isEmpty())
        {
            throw new BizException(ErrorCode.PET_1001, "至少需要一个SKU");
        }
        Set<String> specs = new HashSet<>();
        for (SkuRequest sku : skus)
        {
            if (!specs.add(sku.specName().trim()))
            {
                throw new BizException(ErrorCode.PET_1001, "规格名不能重复：" + sku.specName());
            }
        }
        return skus;
    }

    private void saveSkus(Long itemId, List<SkuRequest> skus)
    {
        for (SkuRequest request : skus)
        {
            PetItemSku sku = new PetItemSku();
            sku.setItemId(itemId);
            sku.setSpecName(request.specName().trim());
            sku.setPrice(request.price());
            sku.setStock(request.stock());
            sku.setSkuCode(request.skuCode());
            sku.setImage(request.image());
            sku.setStatus(request.status() == null ? 1 : request.status());
            skuMapper.insert(sku);
        }
    }

    private void upsertSkus(Long itemId, List<SkuRequest> requests)
    {
        List<PetItemSku> existing = skuMapper.selectByItemId(itemId, false);
        Map<Long, PetItemSku> index = new HashMap<>();
        for (PetItemSku sku : existing)
        {
            index.put(sku.getId(), sku);
        }
        Set<Long> kept = new HashSet<>();
        for (SkuRequest request : requireSkus(requests))
        {
            if (request.id() != null && index.containsKey(request.id()))
            {
                PetItemSku sku = index.get(request.id());
                sku.setSpecName(request.specName().trim());
                sku.setPrice(request.price());
                sku.setStock(request.stock());
                sku.setSkuCode(request.skuCode());
                sku.setImage(request.image());
                sku.setStatus(request.status() == null ? 1 : request.status());
                skuMapper.update(sku);
                kept.add(sku.getId());
            }
            else
            {
                PetItemSku sku = new PetItemSku();
                sku.setItemId(itemId);
                sku.setSpecName(request.specName().trim());
                sku.setPrice(request.price());
                sku.setStock(request.stock());
                sku.setSkuCode(request.skuCode());
                sku.setImage(request.image());
                sku.setStatus(request.status() == null ? 1 : request.status());
                skuMapper.insert(sku);
            }
        }
        for (PetItemSku sku : existing)
        {
            if (!kept.contains(sku.getId()) && (sku.getStatus() == null || sku.getStatus() != 0))
            {
                sku.setStatus(0);
                skuMapper.update(sku);
            }
        }
    }

    private void saveImages(Long itemId, List<ImageRequest> images, String mainImage)
    {
        if (images == null || images.isEmpty())
        {
            PetItemImage image = new PetItemImage();
            image.setItemId(itemId);
            image.setUrl(mainImage);
            image.setSort(0);
            imageMapper.insert(image);
            return;
        }
        int index = 0;
        for (ImageRequest request : images)
        {
            PetItemImage image = new PetItemImage();
            image.setItemId(itemId);
            image.setUrl(request.url());
            image.setSort(request.sort() == null ? index : request.sort());
            imageMapper.insert(image);
            index++;
        }
    }

    private BigDecimal minPrice(List<SkuRequest> skus)
    {
        BigDecimal min = null;
        for (SkuRequest sku : skus)
        {
            if (sku.status() == null || sku.status() == 1)
            {
                if (min == null || sku.price().compareTo(min) < 0)
                {
                    min = sku.price();
                }
            }
        }
        return min == null ? BigDecimal.ZERO : min;
    }

    private BigDecimal minPriceOfEnabled(Long itemId)
    {
        List<PetItemSku> skus = skuMapper.selectByItemId(itemId, true);
        if (skus.isEmpty())
        {
            return BigDecimal.ZERO;
        }
        BigDecimal min = skus.get(0).getPrice();
        for (PetItemSku sku : skus)
        {
            if (sku.getPrice().compareTo(min) < 0)
            {
                min = sku.getPrice();
            }
        }
        return min;
    }

    private Map<String, Object> publicQuery(ItemQuery query)
    {
        Map<String, Object> params = new HashMap<>();
        params.put("keyword", StringUtils.trim(query.keyword()));
        params.put("species", query.species());
        params.put("ageStage", query.ageStage());
        params.put("minPrice", query.minPrice());
        params.put("maxPrice", query.maxPrice());
        params.put("sort", query.sort());
        if (query.categoryId() != null)
        {
            params.put("categoryIds", categoryService.descendantIds(query.categoryId()));
        }
        return params;
    }

    private Map<String, Object> adminQuery(ItemQuery query, Long merchantId)
    {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("keyword", StringUtils.trim(query.keyword()));
        params.put("auditStatus", query.auditStatus());
        params.put("status", query.status());
        params.put("merchantId", merchantId == null ? query.merchantId() : merchantId);
        if (query.categoryId() != null)
        {
            params.put("categoryIds", categoryService.descendantIds(query.categoryId()));
        }
        return params;
    }
}
