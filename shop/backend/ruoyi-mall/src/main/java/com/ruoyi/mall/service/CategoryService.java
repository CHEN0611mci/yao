package com.ruoyi.mall.service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.domain.PetCategory;
import com.ruoyi.mall.dto.CategoryRequest;
import com.ruoyi.mall.mapper.PetCategoryMapper;
import com.ruoyi.mall.mapper.PetItemMapper;

/**
 * 商品分类服务：最多两级，删除前校验引用。
 *
 * @author ruoyi
 */
@Service
public class CategoryService
{
    @Autowired
    private PetCategoryMapper categoryMapper;

    @Autowired
    private PetItemMapper itemMapper;

    public List<PetCategory> tree(boolean onlyEnabled)
    {
        List<PetCategory> all = categoryMapper.selectList(onlyEnabled ? 0 : null);
        return buildTree(all);
    }

    public PetCategory get(Long id)
    {
        PetCategory category = categoryMapper.selectById(id);
        if (category == null)
        {
            throw new BizException(ErrorCode.PET_1001, "分类不存在");
        }
        return category;
    }

    @Transactional(rollbackFor = Exception.class)
    public PetCategory create(CategoryRequest request)
    {
        verifyParent(request.parentId(), null);
        PetCategory category = new PetCategory();
        apply(category, request);
        categoryMapper.insert(category);
        return categoryMapper.selectById(category.getId());
    }

    @Transactional(rollbackFor = Exception.class)
    public PetCategory update(Long id, CategoryRequest request)
    {
        PetCategory category = get(id);
        verifyParent(request.parentId(), id);
        apply(category, request);
        categoryMapper.update(category);
        return categoryMapper.selectById(id);
    }

    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id)
    {
        get(id);
        if (categoryMapper.countChildren(id) > 0)
        {
            throw new BizException(ErrorCode.PET_1003, "请先删除子分类");
        }
        if (itemMapper.countByCategory(id) > 0)
        {
            throw new BizException(ErrorCode.PET_1003, "分类下存在商品，无法删除");
        }
        categoryMapper.delete(id);
    }

    /**
     * 返回自身及全部下级分类 ID，用于按父分类筛选商品。
     */
    public List<Long> descendantIds(Long categoryId)
    {
        if (categoryId == null)
        {
            return new ArrayList<>();
        }
        List<PetCategory> all = categoryMapper.selectList(null);
        Set<Long> result = new LinkedHashSet<>();
        result.add(categoryId);
        boolean changed = true;
        while (changed)
        {
            changed = false;
            for (PetCategory category : all)
            {
                if (category.getParentId() != null && result.contains(category.getParentId())
                        && result.add(category.getId()))
                {
                    changed = true;
                }
            }
        }
        return new ArrayList<>(result);
    }

    private List<PetCategory> buildTree(List<PetCategory> all)
    {
        Map<Long, PetCategory> index = new LinkedHashMap<>();
        for (PetCategory category : all)
        {
            category.setChildren(new ArrayList<>());
            index.put(category.getId(), category);
        }
        List<PetCategory> roots = new ArrayList<>();
        for (PetCategory category : all)
        {
            PetCategory parent = category.getParentId() == null ? null : index.get(category.getParentId());
            if (parent != null && !parent.getId().equals(category.getId()))
            {
                parent.getChildren().add(category);
            }
            else
            {
                roots.add(category);
            }
        }
        return roots;
    }

    private void verifyParent(Long parentId, Long selfId)
    {
        if (parentId == null || parentId == 0L)
        {
            return;
        }
        if (selfId != null && selfId.equals(parentId))
        {
            throw new BizException(ErrorCode.PET_1001, "上级分类不能是自己");
        }
        PetCategory parent = categoryMapper.selectById(parentId);
        if (parent == null)
        {
            throw new BizException(ErrorCode.PET_1001, "上级分类不存在");
        }
        if (parent.getParentId() != null && parent.getParentId() != 0L)
        {
            throw new BizException(ErrorCode.PET_1001, "分类最多支持两级");
        }
        if (selfId != null && new HashSet<>(descendantIds(selfId)).contains(parentId))
        {
            throw new BizException(ErrorCode.PET_1001, "上级分类不能是自己的下级");
        }
    }

    private void apply(PetCategory category, CategoryRequest request)
    {
        category.setParentId(request.parentId() == null ? 0L : request.parentId());
        category.setName(request.name().trim());
        category.setIcon(request.icon());
        category.setSort(request.sort() == null ? 0 : request.sort());
        category.setPetScope(request.petScope() == null || request.petScope().isEmpty()
                ? "ALL" : request.petScope());
        category.setStatus(request.status() == null ? 0 : request.status());
    }
}
