-- ============================================================================
-- 萌宠优选 · 宠物商城系统  数据库校验脚本（只读，不修改数据）
-- 用途：建库建表后一键校验表数量、种子数据量、约束/索引与一致性对账
-- 执行：mysql -uroot -p --default-character-set=utf8mb4 < db/verify.sql
-- 判定：result 列全部为 PASS 即通过；CONCAT 中给出实际值便于排查
-- ============================================================================
SET NAMES utf8mb4;
USE `shop`;

-- ----------------------------
-- A. 库与表结构
-- ----------------------------
SELECT 'A01 库表总数 = 45（若依 31 + 业务 14）' AS check_item,
       IF(COUNT(*) = 45, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) AS result
FROM information_schema.tables WHERE table_schema = 'shop'
UNION ALL
SELECT 'A02 业务表数 = 14',
       IF(COUNT(*) = 14, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM information_schema.tables
WHERE table_schema = 'shop' AND LEFT(table_name, 4) = 'pet_'
UNION ALL
SELECT 'A03 业务表字符集均为 utf8mb4_general_ci',
       IF(COUNT(*) = 14, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM information_schema.tables
WHERE table_schema = 'shop' AND LEFT(table_name, 4) = 'pet_'
  AND table_collation = 'utf8mb4_general_ci'
UNION ALL
SELECT 'A04 唯一索引数 = 9（不含主键）',
       IF(COUNT(DISTINCT table_name, index_name) = 9, 'PASS',
          CONCAT('FAIL(', COUNT(DISTINCT table_name, index_name), ')'))
FROM information_schema.statistics
WHERE table_schema = 'shop' AND LEFT(table_name, 4) = 'pet_'
  AND non_unique = 0 AND index_name <> 'PRIMARY'
UNION ALL
SELECT 'A05 CHECK 约束数 = 5',
       IF(COUNT(*) = 5, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM information_schema.table_constraints
WHERE table_schema = 'shop' AND constraint_type = 'CHECK'
UNION ALL
SELECT 'A06 表注释完整（14 张均有注释）',
       IF(COUNT(*) = 14, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM information_schema.tables
WHERE table_schema = 'shop' AND LEFT(table_name, 4) = 'pet_'
  AND table_comment <> '';

-- ----------------------------
-- B. 种子数据量（对应需求 §7.7 / 设计 §6.8）
-- ----------------------------
SELECT 'B01 会员 = 2' AS check_item,
       IF(COUNT(*) = 2, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) AS result FROM pet_member
UNION ALL SELECT 'B02 宠物档案 = 3', IF(COUNT(*) = 3, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_member_pet
UNION ALL SELECT 'B03 收货地址 = 3', IF(COUNT(*) = 3, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_address
UNION ALL SELECT 'B04 分类 = 8（一级 4 / 二级 4）',
       IF((SELECT COUNT(*) FROM pet_category) = 8
          AND (SELECT COUNT(*) FROM pet_category WHERE parent_id = 0) = 4
          AND (SELECT COUNT(*) FROM pet_category WHERE parent_id <> 0) = 4, 'PASS', 'FAIL')
UNION ALL SELECT 'B05 商品 = 12', IF(COUNT(*) = 12, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_item
UNION ALL SELECT 'B06 商品审核状态（待审 1 / 驳回 1 / 通过 10）',
       IF((SELECT COUNT(*) FROM pet_item WHERE audit_status = 0) = 1
          AND (SELECT COUNT(*) FROM pet_item WHERE audit_status = 1) = 1
          AND (SELECT COUNT(*) FROM pet_item WHERE audit_status = 2) = 10, 'PASS', 'FAIL')
UNION ALL SELECT 'B07 SKU = 24', IF(COUNT(*) = 24, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_item_sku
UNION ALL SELECT 'B08 演示库存：至少 1 个 stock=1、1 个 stock=0',
       IF((SELECT COUNT(*) FROM pet_item_sku WHERE stock = 1) >= 1
          AND (SELECT COUNT(*) FROM pet_item_sku WHERE stock = 0) >= 1, 'PASS', 'FAIL')
UNION ALL SELECT 'B09 订单 = 2（待付款 1 / 已完成 1）',
       IF(COUNT(*) = 2
          AND (SELECT COUNT(*) FROM pet_order WHERE status = 0) = 1
          AND (SELECT COUNT(*) FROM pet_order WHERE status = 4) = 1, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_order
UNION ALL SELECT 'B10 订单明细 = 3', IF(COUNT(*) = 3, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_order_item
UNION ALL SELECT 'B11 支付记录 = 1', IF(COUNT(*) = 1, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_payment
UNION ALL SELECT 'B12 库存流水 = 27（24 ADJUST + 3 DEDUCT）',
       IF(COUNT(*) = 27
          AND (SELECT COUNT(*) FROM pet_stock_log WHERE type = 'ADJUST') = 24
          AND (SELECT COUNT(*) FROM pet_stock_log WHERE type = 'DEDUCT') = 3, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_stock_log
UNION ALL SELECT 'B13 系统参数 mall.* = 8',
       IF(COUNT(*) = 8, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM sys_config WHERE config_key LIKE 'mall.%'
UNION ALL SELECT 'B14 商城菜单 = 26', IF(COUNT(*) = 26, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM sys_menu WHERE menu_id BETWEEN 3000 AND 3299
UNION ALL SELECT 'B15 后台演示角色 = 2（商家/审核员）',
       IF(COUNT(*) = 2, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM sys_role WHERE role_id IN (100, 101)
UNION ALL SELECT 'B16 后台演示账号 = 2（merchant1/reviewer）+ admin',
       IF((SELECT COUNT(*) FROM sys_user WHERE user_name IN ('merchant1', 'reviewer')) = 2
          AND (SELECT COUNT(*) FROM sys_user WHERE user_name = 'admin') = 1, 'PASS', 'FAIL')
UNION ALL SELECT 'B17 后台账号密码均为 BCrypt 哈希',
       IF((SELECT COUNT(*) FROM sys_user WHERE user_name IN ('admin', 'merchant1', 'reviewer')
           AND password LIKE '$2a$10$%') = 3, 'PASS', 'FAIL')
UNION ALL SELECT 'B18 购物车 = 2', IF(COUNT(*) = 2, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_cart_item
UNION ALL SELECT 'B19 站内消息 = 2', IF(COUNT(*) = 2, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_message
UNION ALL SELECT 'B20 审核留痕 = 11', IF(COUNT(*) = 11, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) FROM pet_item_audit;

-- ----------------------------
-- C. 一致性 / 完整性对账（设计 §6.7）
-- ----------------------------
SELECT 'C01 库存对账：Σchange_qty = 当前库存（不一致行数 = 0）' AS check_item,
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')')) AS result
FROM (
  SELECT s.id, s.stock, COALESCE(SUM(l.change_qty), 0) AS flow_sum
  FROM pet_item_sku s
  LEFT JOIN pet_stock_log l ON l.sku_id = s.id
  GROUP BY s.id, s.stock
  HAVING flow_sum <> s.stock
) t
UNION ALL
SELECT 'C02 订单金额自洽：总额=Σ明细，应付=总额+运费-优惠（不一致行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM (
  SELECT o.id
  FROM pet_order o
  JOIN pet_order_item i ON i.order_id = o.id
  GROUP BY o.id, o.total_amount, o.freight, o.discount_amount, o.pay_amount
  HAVING o.total_amount <> SUM(i.amount)
      OR o.pay_amount <> o.total_amount + o.freight - o.discount_amount
) t
UNION ALL
SELECT 'C03 明细金额 = 单价 × 数量（不一致行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_order_item WHERE amount <> price * quantity
UNION ALL
SELECT 'C04 已支付订单必有成功支付记录且金额一致（不一致行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM (
  SELECT o.order_no
  FROM pet_order o
  LEFT JOIN pet_payment p ON p.order_no = o.order_no AND p.status = 'SUCCESS'
  WHERE o.status IN (2, 3, 4, 8)
    AND (p.id IS NULL OR p.amount <> o.pay_amount)
) t
UNION ALL
SELECT 'C05 商品 price_min = 最低 SKU 价（不一致行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM (
  SELECT i.id
  FROM pet_item i
  JOIN pet_item_sku s ON s.item_id = i.id
  GROUP BY i.id, i.price_min
  HAVING i.price_min <> MIN(s.price)
) t
UNION ALL
SELECT 'C06 订单状态均在 0-8 范围内（非法行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_order WHERE status NOT BETWEEN 0 AND 8
UNION ALL
SELECT 'C07 默认地址唯一（每会员至多 1 条，冲突会员数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM (
  SELECT member_id FROM pet_address WHERE is_default = 1 GROUP BY member_id HAVING COUNT(*) > 1
) t
UNION ALL
SELECT 'C08 待付款订单支付截止时间未过期（过期行数 = 0）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_order WHERE status = 0 AND expire_at <= NOW()
UNION ALL
SELECT 'C09 每条 ADJUST 初始库存流水 order_no 为空串（防唯一键 NULL 失效）',
       IF(COUNT(*) = 0, 'PASS', CONCAT('FAIL(', COUNT(*), ')'))
FROM pet_stock_log WHERE type = 'ADJUST' AND order_no <> '';

-- ----------------------------
-- D. 常用查询路径（供索引验证参考）
-- ----------------------------
SELECT 'D01 索引总数（pet_*）' AS check_item, COUNT(DISTINCT table_name, index_name) AS result
FROM information_schema.statistics
WHERE table_schema = 'shop' AND LEFT(table_name, 4) = 'pet_'
UNION ALL
SELECT 'D02 表数量（pet_* + sys_* + qrtz_* + gen_*）', COUNT(*) FROM information_schema.tables WHERE table_schema = 'shop';
