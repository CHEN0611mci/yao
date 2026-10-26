package com.ruoyi.mall.domain;

import java.io.Serializable;
import java.util.Date;
import java.math.BigDecimal;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * PetOrder 商城业务实体。
 *
 * @author ruoyi
 */
public class PetOrder implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long id;
    private String orderNo;
    private Long memberId;
    private Long merchantId;
    private BigDecimal totalAmount;
    private BigDecimal discountAmount;
    private BigDecimal freight;
    private BigDecimal payAmount;
    private Integer status;
    private String receiverSnapshot;
    private String petSnapshot;
    private String remark;
    private String clientToken;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date expireAt;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date payTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date shipTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date receiveTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date closeTime;
    private String cancelReason;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date createTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date updateTime;
    private List<PetOrderItem> items;
    private PetPayment payment;
    private List<PetStockLog> stockLogs;
    private String statusText;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public String getOrderNo()
    {
        return orderNo;
    }

    public void setOrderNo(String orderNo)
    {
        this.orderNo = orderNo;
    }

    public Long getMemberId()
    {
        return memberId;
    }

    public void setMemberId(Long memberId)
    {
        this.memberId = memberId;
    }

    public Long getMerchantId()
    {
        return merchantId;
    }

    public void setMerchantId(Long merchantId)
    {
        this.merchantId = merchantId;
    }

    public BigDecimal getTotalAmount()
    {
        return totalAmount;
    }

    public void setTotalAmount(BigDecimal totalAmount)
    {
        this.totalAmount = totalAmount;
    }

    public BigDecimal getDiscountAmount()
    {
        return discountAmount;
    }

    public void setDiscountAmount(BigDecimal discountAmount)
    {
        this.discountAmount = discountAmount;
    }

    public BigDecimal getFreight()
    {
        return freight;
    }

    public void setFreight(BigDecimal freight)
    {
        this.freight = freight;
    }

    public BigDecimal getPayAmount()
    {
        return payAmount;
    }

    public void setPayAmount(BigDecimal payAmount)
    {
        this.payAmount = payAmount;
    }

    public Integer getStatus()
    {
        return status;
    }

    public void setStatus(Integer status)
    {
        this.status = status;
    }

    public String getReceiverSnapshot()
    {
        return receiverSnapshot;
    }

    public void setReceiverSnapshot(String receiverSnapshot)
    {
        this.receiverSnapshot = receiverSnapshot;
    }

    public String getPetSnapshot()
    {
        return petSnapshot;
    }

    public void setPetSnapshot(String petSnapshot)
    {
        this.petSnapshot = petSnapshot;
    }

    public String getRemark()
    {
        return remark;
    }

    public void setRemark(String remark)
    {
        this.remark = remark;
    }

    public String getClientToken()
    {
        return clientToken;
    }

    public void setClientToken(String clientToken)
    {
        this.clientToken = clientToken;
    }

    public Date getExpireAt()
    {
        return expireAt;
    }

    public void setExpireAt(Date expireAt)
    {
        this.expireAt = expireAt;
    }

    public Date getPayTime()
    {
        return payTime;
    }

    public void setPayTime(Date payTime)
    {
        this.payTime = payTime;
    }

    public Date getShipTime()
    {
        return shipTime;
    }

    public void setShipTime(Date shipTime)
    {
        this.shipTime = shipTime;
    }

    public Date getReceiveTime()
    {
        return receiveTime;
    }

    public void setReceiveTime(Date receiveTime)
    {
        this.receiveTime = receiveTime;
    }

    public Date getCloseTime()
    {
        return closeTime;
    }

    public void setCloseTime(Date closeTime)
    {
        this.closeTime = closeTime;
    }

    public String getCancelReason()
    {
        return cancelReason;
    }

    public void setCancelReason(String cancelReason)
    {
        this.cancelReason = cancelReason;
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

    public List<PetOrderItem> getItems()
    {
        return items;
    }

    public void setItems(List<PetOrderItem> items)
    {
        this.items = items;
    }

    public PetPayment getPayment()
    {
        return payment;
    }

    public void setPayment(PetPayment payment)
    {
        this.payment = payment;
    }

    public List<PetStockLog> getStockLogs()
    {
        return stockLogs;
    }

    public void setStockLogs(List<PetStockLog> stockLogs)
    {
        this.stockLogs = stockLogs;
    }

    public String getStatusText()
    {
        return statusText;
    }

    public void setStatusText(String statusText)
    {
        this.statusText = statusText;
    }
}
