package com.ruoyi.mall.domain;

import java.io.Serializable;
import java.util.Date;
import java.math.BigDecimal;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * PetItem 商城业务实体。
 *
 * @author ruoyi
 */
public class PetItem implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long id;
    private Long categoryId;
    private Long merchantId;
    private String title;
    private String subtitle;
    private String mainImage;
    private String brand;
    private String petSpecies;
    private String ageStage;
    private String weightRange;
    private BigDecimal priceMin;
    private BigDecimal costPrice;
    private Integer supportSubscribe;
    private Integer isPrescription;
    private String detail;
    private Integer auditStatus;
    private Integer status;
    private Integer sales;
    private String delFlag;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date createTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date updateTime;
    private List<PetItemSku> skus;
    private List<PetItemImage> images;
    private List<PetItemAudit> audits;
    private com.ruoyi.mall.dto.AdaptResult adapt;
    private List<com.ruoyi.mall.dto.AdaptResult> adapts;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getCategoryId()
    {
        return categoryId;
    }

    public void setCategoryId(Long categoryId)
    {
        this.categoryId = categoryId;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public String getTitle()
    {
        return title;
    }

    public void setTitle(String title)
    {
        this.title = title;
    }

    public String getSubtitle()
    {
        return subtitle;
    }

    public void setSubtitle(String subtitle)
    {
        this.subtitle = subtitle;
    }

    public String getMainImage()
    {
        return mainImage;
    }

    public void setMainImage(String mainImage)
    {
        this.mainImage = mainImage;
    }

    public String getBrand()
    {
        return brand;
    }

    public void setBrand(String brand)
    {
        this.brand = brand;
    }

    public String getPetSpecies()
    {
        return petSpecies;
    }

    public void setPetSpecies(String petSpecies)
    {
        this.petSpecies = petSpecies;
    }

    public String getAgeStage()
    {
        return ageStage;
    }

    public void setAgeStage(String ageStage)
    {
        this.ageStage = ageStage;
    }

    public String getWeightRange()
    {
        return weightRange;
    }

    public void setWeightRange(String weightRange)
    {
        this.weightRange = weightRange;
    }

    public BigDecimal getPriceMin()
    {
        return priceMin;
    }

    public void setPriceMin(BigDecimal priceMin)
    {
        this.priceMin = priceMin;
    }

    public BigDecimal getCostPrice()
    {
        return costPrice;
    }

    public void setCostPrice(BigDecimal costPrice)
    {
        this.costPrice = costPrice;
    }

    public Integer getSupportSubscribe()
    {
        return supportSubscribe;
    }

    public void setSupportSubscribe(Integer supportSubscribe)
    {
        this.supportSubscribe = supportSubscribe;
    }

    public Integer getIsPrescription()
    {
        return isPrescription;
    }

    public void setIsPrescription(Integer isPrescription)
    {
        this.isPrescription = isPrescription;
    }

    public String getDetail()
    {
        return detail;
    }

    public void setDetail(String detail)
    {
        this.detail = detail;
    }

    public Integer getAuditStatus()
    {
        return auditStatus;
    }

    public void setAuditStatus(Integer auditStatus)
    {
        this.auditStatus = auditStatus;
    }

    public Integer getStatus()
    {
        return status;
    }

    public void setStatus(Integer status)
    {
        this.status = status;
    }

    public Integer getSales()
    {
        return sales;
    }

    public void setSales(Integer sales)
    {
        this.sales = sales;
    }

    public String getDelFlag()
    {
        return delFlag;
    }

    public void setDelFlag(String delFlag)
    {
        this.delFlag = delFlag;
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

    public List<PetItemSku> getSkus()
    {
        return skus;
    }

    public void setSkus(List<PetItemSku> skus)
    {
        this.skus = skus;
    }

    public List<PetItemImage> getImages()
    {
        return images;
    }

    public void setImages(List<PetItemImage> images)
    {
        this.images = images;
    }

    public List<PetItemAudit> getAudits()
    {
        return audits;
    }

    public void setAudits(List<PetItemAudit> audits)
    {
        this.audits = audits;
    }

    public com.ruoyi.mall.dto.AdaptResult getAdapt()
    {
        return adapt;
    }

    public void setAdapt(com.ruoyi.mall.dto.AdaptResult adapt)
    {
        this.adapt = adapt;
    }

    public List<com.ruoyi.mall.dto.AdaptResult> getAdapts()
    {
        return adapts;
    }

    public void setAdapts(List<com.ruoyi.mall.dto.AdaptResult> adapts)
    {
        this.adapts = adapts;
    }
}
