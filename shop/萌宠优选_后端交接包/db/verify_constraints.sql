-- ============================================================================
-- 萌宠优选 · 宠物商城系统  约束与并发语义实测脚本（预期产生报错，不污染数据）
-- 用途：验证 CHECK 约束、唯一索引、条件扣减（防超卖）语义
-- 执行：mysql -uroot -p --force --default-character-set=utf8mb4 < db/verify_constraints.sql
-- 说明：
--   1. 每个用例包在事务中并 ROLLBACK，即使约束缺失导致插入成功也不会留下数据；
--   2. 前 8 个用例为"预期失败"：必须出现 ERROR 3819（CHECK）或 ERROR 1062（唯一键），
--      若没有报错则说明约束缺失，属于缺陷；
--   3. 最后 2 个用例为"预期成功"：条件扣减第 1 次影响 1 行、第 2 次影响 0 行。
-- 参考结果：db/evidence/constraint_test_result.txt
-- ============================================================================
SET NAMES utf8mb4;
USE `shop`;

-- T01 负库存 → chk_sku_stock（预期 ERROR 3819）
START TRANSACTION;
INSERT INTO pet_item_sku (item_id, spec_name, price, stock, sku_code)
VALUES (1, '非法库存测试', 1.00, -1, 'TMP-NEG');
ROLLBACK;

-- T02 价格为 0 → chk_sku_price（预期 ERROR 3819）
START TRANSACTION;
INSERT INTO pet_item_sku (item_id, spec_name, price, stock)
VALUES (1, '非法价格测试', 0.00, 10);
ROLLBACK;

-- T03 购物车数量 0 → chk_cart_qty（预期 ERROR 3819）
START TRANSACTION;
INSERT INTO pet_cart_item (member_id, item_id, sku_id, quantity) VALUES (1001, 1, 1, 0);
ROLLBACK;

-- T04 宠物体重 200kg → chk_pet_weight（预期 ERROR 3819）
START TRANSACTION;
INSERT INTO pet_member_pet (member_id, name, species, weight) VALUES (1001, 'x', 'CAT', 200);
ROLLBACK;

-- T05 订单应付金额为负 → chk_order_amount（预期 ERROR 3819）
START TRANSACTION;
INSERT INTO pet_order
  (order_no, member_id, merchant_id, total_amount, pay_amount, status, receiver_snapshot, expire_at)
VALUES ('PET-TMP-NEG', 1001, 9001, 10.00, -1.00, 0, '{}', NOW());
ROLLBACK;

-- T06 重复用户名 → uk_username（预期 ERROR 1062）
START TRANSACTION;
INSERT INTO pet_member (username, password, nickname) VALUES ('member1', 'x', 'dup');
ROLLBACK;

-- T07 重复支付幂等键 → uk_idempotency_key（预期 ERROR 1062，幂等重放不会重复入账）
START TRANSACTION;
INSERT INTO pet_payment
  (payment_no, order_no, amount, channel, status, idempotency_key)
VALUES ('PAY-TMP', 'PET202610190900000001', 99.00, 'WECHAT', 'SUCCESS',
        'seed-order-0002-pay-0001');
ROLLBACK;

-- T08 重复库存流水组合键 → uk_sku_order_type（预期 ERROR 1062，防重复扣减/回滚）
START TRANSACTION;
INSERT INTO pet_stock_log
  (sku_id, order_no, type, change_qty, before_qty, after_qty)
VALUES (1, 'PET202610190900000001', 'DEDUCT', -1, 120, 119);
ROLLBACK;

-- T09/T10 条件扣减语义：库存 1 的 SKU 连续扣减两次（预期影响行数 1 → 0）
START TRANSACTION;
UPDATE pet_item_sku SET stock = stock - 1 WHERE id = 5 AND stock >= 1;
SELECT 'T09 条件扣减第 1 次影响行数（应为 1）' AS test_item, ROW_COUNT() AS result;
UPDATE pet_item_sku SET stock = stock - 1 WHERE id = 5 AND stock >= 1;
SELECT 'T10 条件扣减第 2 次影响行数（应为 0，库存不足不扣减）' AS test_item, ROW_COUNT() AS result;
ROLLBACK;
