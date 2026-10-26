package com.ruoyi.mall.domain;

import java.io.Serializable;
import java.util.Date;
import java.math.BigDecimal;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * PetCartItem 商城业务实体。
 *
 * @author ruoyi
 */
public class PetCartItem implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long id;
    private Long memberId;
    private Long itemId;
    private Long skuId;
    private Integer quantity;
    private Integer checked;
    private Long petId;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date createTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date updateTime;
    private PetItem item;
    private PetItemSku sku;
    private BigDecimal amount;
    private Boolean valid;
    private String invalidReason;
    private String petName;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getMemberId()
    {
        return memberId;
    }

    public void setMemberId(Long memberId)
    {
        this.memberId = memberId;
    }

    public Long getItemId()
    {
        return itemId;
    }

    public void setItemId(Long itemId)
    {
        this.itemId = itemId;
    }

    public Long getSkuId()
    {
        return skuId;
    }

    public void setSkuId(Long skuId)
    {
        this.skuId = skuId;
    }

    public Integer getQuantity()
    {
        return quantity;
    }

    public void setQuantity(Integer quantity)
    {
        this.quantity = quantity;
    }

    public Integer getChecked()
    {
        return checked;
    }

    public void setChecked(Integer checked)
    {
        this.checked = checked;
    }

    public Long getPetId()
    {
        return petId;
    }

    public void setPetId(Long petId)
    {
        this.petId = petId;
    }

    public Date getCreateTime()
    {
        return createTime;
    }

    public void setCreateTime(Date createTime)
    {
        this.createTime = createTime;
    }

    public Date getUpdateTime()
    {
        return updateTime;
    }

    public void setUpdateTime(Date updateTime)
    {
        this.updateTime = updateTime;
    }

    public PetItem getItem()
    {
        return item;
    }

    public void setItem(PetItem item)
    {
        this.item = item;
    }

    public PetItemSku getSku()
    {
        return sku;
    }

    public void setSku(PetItemSku sku)
    {
        this.sku = sku;
    }

    public BigDecimal getAmount()
    {
        return amount;
    }

    public void setAmount(BigDecimal amount)
    {
        this.amount = amount;
    }

    public Boolean getValid()
    {
        return valid;
    }

    public void setValid(Boolean valid)
    {
        this.valid = valid;
    }

    public String getInvalidReason()
    {
        return invalidReason;
    }

    public void setInvalidReason(String invalidReason)
    {
        this.invalidReason = invalidReason;
    }

    public String getPetName()
    {
        return petName;
    }

    public void setPetName(String petName)
    {
        this.petName = petName;
    }
}
