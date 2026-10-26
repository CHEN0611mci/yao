package com.ruoyi.mall.domain;

import java.io.Serializable;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * PetStockLog 商城业务实体。
 *
 * @author ruoyi
 */
public class PetStockLog implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long id;
    private Long skuId;
    private String orderNo;
    private String type;
    private Integer changeQty;
    private Integer beforeQty;
    private Integer afterQty;
    private String operator;
    private String remark;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date createTime;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getSkuId()
    {
        return skuId;
    }

    public void setSkuId(Long skuId)
    {
        this.skuId = skuId;
    }

    public String getOrderNo()
    {
        return orderNo;
    }

    public void setOrderNo(String orderNo)
    {
        this.orderNo = orderNo;
    }

    public String getType()
    {
        return type;
    }

    public void setType(String type)
    {
        this.type = type;
    }

    public Integer getChangeQty()
    {
        return changeQty;
    }

    public void setChangeQty(Integer changeQty)
    {
        this.changeQty = changeQty;
    }

    public Integer getBeforeQty()
    {
        return beforeQty;
    }

    public void setBeforeQty(Integer beforeQty)
    {
        this.beforeQty = beforeQty;
    }

    public Integer getAfterQty()
    {
        return afterQty;
    }

    public void setAfterQty(Integer afterQty)
    {
        this.afterQty = afterQty;
    }

    public String getOperator()
    {
        return operator;
    }

    public void setOperator(String operator)
    {
        this.operator = operator;
    }

    public String getRemark()
    {
        return remark;
    }

    public void setRemark(String remark)
    {
        this.remark = remark;
    }

    public Date getCreateTime()
    {
        return createTime;
    }

    public void setCreateTime(Date createTime)
    {
        this.createTime = createTime;
    }
}
