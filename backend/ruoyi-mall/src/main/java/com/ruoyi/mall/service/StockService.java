package com.ruoyi.mall.service;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.domain.PetItemSku;
import com.ruoyi.mall.domain.PetStockLog;
import com.ruoyi.mall.mapper.PetItemSkuMapper;
import com.ruoyi.mall.mapper.PetStockLogMapper;

/**
 * 库存服务：条件扣减防止超卖，回滚与流水留痕。
 *
 * @author ruoyi
 */
@Service
public class StockService
{
    public static final String TYPE_ORDER_DEDUCT = "ORDER_DEDUCT";
    public static final String TYPE_ORDER_ROLLBACK = "ORDER_ROLLBACK";
    public static final String TYPE_MANUAL = "MANUAL";

    @Autowired
    private PetItemSkuMapper skuMapper;

    @Autowired
    private PetStockLogMapper stockLogMapper;

    /**
     * 原子扣减库存；where stock >= qty 保证并发下不超卖。
     */
    @Transactional(rollbackFor = Exception.class)
    public void deduct(Long skuId, int quantity, String orderNo, String operator, String remark)
    {
        if (quantity <= 0)
        {
            return;
        }
        PetItemSku locked = skuMapper.selectForUpdate(skuId);
        if (locked == null) throw new BizException(ErrorCode.PET_3003, "SKU不存在");
        if (stockLogMapper.countBySkuOrderType(skuId, orderNo, TYPE_ORDER_DEDUCT) > 0)
        {
            return;
        }
        Integer before = locked.getStock();
        if (before == null)
        {
            throw new BizException(ErrorCode.PET_3003, "SKU不存在");
        }
        int rows = skuMapper.deductStock(skuId, quantity);
        if (rows == 0)
        {
            throw new BizException(ErrorCode.PET_3001, "库存不足，请调整购买数量");
        }
        writeLog(skuId, orderNo, TYPE_ORDER_DEDUCT, -quantity, before, before - quantity, operator, remark);
    }

    @Transactional(rollbackFor = Exception.class)
    public void rollback(Long skuId, int quantity, String orderNo, String operator, String remark)
    {
        if (quantity <= 0)
        {
            return;
        }
        PetItemSku locked = skuMapper.selectForUpdate(skuId);
        if (locked == null) throw new BizException(ErrorCode.PET_3003, "SKU不存在");
        if (stockLogMapper.countBySkuOrderType(skuId, orderNo, TYPE_ORDER_ROLLBACK) > 0)
        {
            return;
        }
        Integer before = locked.getStock();
        if (before == null)
        {
            throw new BizException(ErrorCode.PET_3003, "SKU不存在");
        }
        skuMapper.increaseStock(skuId, quantity);
        writeLog(skuId, orderNo, TYPE_ORDER_ROLLBACK, quantity, before, before + quantity, operator, remark);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetItemSku adjust(Long skuId, int targetStock, String operator, String remark)
    {
        if (targetStock < 0)
        {
            throw new BizException(ErrorCode.PET_1001, "库存不能为负");
        }
        PetItemSku sku = skuMapper.selectForUpdate(skuId);
        if (sku == null)
        {
            throw new BizException(ErrorCode.PET_3003, "SKU不存在");
        }
        int before = sku.getStock() == null ? 0 : sku.getStock();
        int change = targetStock - before;
        if (change > 0)
        {
            skuMapper.increaseStock(skuId, change);
        }
        else if (change < 0)
        {
            int rows = skuMapper.deductStock(skuId, -change);
            if (rows == 0)
            {
                throw new BizException(ErrorCode.PET_3001, "库存不足以调整为" + targetStock);
            }
        }
        if (change != 0)
        {
            writeLog(skuId, null, TYPE_MANUAL, change, before, targetStock, operator, remark);
        }
        return skuMapper.selectById(skuId);
    }

    public List<Map<String, Object>> overview(Map<String, Object> query)
    {
        return skuMapper.selectStockOverview(query);
    }

    public List<PetStockLog> logs(Map<String, Object> query)
    {
        return stockLogMapper.selectList(query);
    }

    private void writeLog(Long skuId, String orderNo, String type, int changeQty, int before, int after,
            String operator, String remark)
    {
        PetStockLog log = new PetStockLog();
        log.setSkuId(skuId);
        // Manual adjustments also need a unique reference: order_no is NOT NULL,
        // and (sku_id, order_no, type) is unique for order deduction/rollback.
        log.setOrderNo(orderNo == null || orderNo.isBlank()
                ? "ADJ" + java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 29) : orderNo);
        log.setType(type);
        log.setChangeQty(changeQty);
        log.setBeforeQty(before);
        log.setAfterQty(after);
        log.setOperator(operator);
        log.setRemark(remark);
        stockLogMapper.insert(log);
    }
}
