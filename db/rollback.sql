-- ============================================================================
-- 萌宠优选 · 宠物商城系统  数据库脚本 rollback：业务表回滚
-- 依据：设计文档 v1.0 §6.9（脚本拆分与执行顺序）、§11.7（备份与回滚）
-- 作用：仅 DROP 14 张 pet_* 业务表，保留若依 sys_*/qrtz_*/gen_* 系统表
-- 执行方式：mysql -uroot -p --default-character-set=utf8mb4 < db/rollback.sql
-- 可重复执行：是
-- 警告：会删除全部业务数据，仅在演示/测试环境或已备份前提下执行
-- ============================================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
USE `shop`;

DROP TABLE IF EXISTS `pet_message`;
DROP TABLE IF EXISTS `pet_stock_log`;
DROP TABLE IF EXISTS `pet_payment`;
DROP TABLE IF EXISTS `pet_order_item`;
DROP TABLE IF EXISTS `pet_order`;
DROP TABLE IF EXISTS `pet_cart_item`;
DROP TABLE IF EXISTS `pet_item_audit`;
DROP TABLE IF EXISTS `pet_item_image`;
DROP TABLE IF EXISTS `pet_item_sku`;
DROP TABLE IF EXISTS `pet_item`;
DROP TABLE IF EXISTS `pet_category`;
DROP TABLE IF EXISTS `pet_address`;
DROP TABLE IF EXISTS `pet_member_pet`;
DROP TABLE IF EXISTS `pet_member`;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 说明：本脚本按设计文档只回滚业务表，若依系统表与账号保持不变。
-- 若需同步清理 03_seed.sql 写入的商城 RBAC 与参数（恢复为纯若依基座），
-- 在确认不再需要商城后台账号后，手工执行以下语句：
--
-- DELETE FROM sys_user_role WHERE user_id IN (3, 4);
-- DELETE FROM sys_user      WHERE user_name IN ('merchant1', 'reviewer');
-- DELETE FROM sys_role_menu WHERE role_id IN (100, 101);
-- DELETE FROM sys_role      WHERE role_id IN (100, 101);
-- DELETE FROM sys_menu      WHERE menu_id BETWEEN 3000 AND 3299;
-- DELETE FROM sys_config    WHERE config_key LIKE 'mall.%';
-- DELETE FROM sys_dept      WHERE dept_id = 9001;
-- ============================================================================
