-- ============================================================================
-- 萌宠优选 · 宠物商城系统
-- 补丁：修复 R-01「商家端与商城管理端同名路由」问题
--
-- 背景（设计文档《管理端前端详细设计 v1.0》§4.2 / §9.5 第 21 项）：
--   sys_menu 3002（商品管理，path=items，component=mall/item/index）与
--   sys_menu 3201（我的商品，path=items，component=mall/merchant/item/index）的 path 相同，
--   且 3005（订单管理 orders）与 3202（我的订单 orders）也相同；
--   两行 route_name 均为空字符串，后端 RouterVo.name = capitalize(route_name || path)
--   => 两组路由名都为 Items / Orders。
--   vue-router 4 遇到同名路由会替换（移除）先注册者，admin 同时拥有两套菜单时，
--   /mall/items、/mall/orders 可能不可达，keep-alive/TagsView 也可能串页。
--
-- 处置：给商家端两行补充全局唯一的 route_name（RuoYi checkRouteConfigUnique 要求全局唯一），
--   前端页面 `<script setup name="...">` 已按 MerchantItems / MerchantOrders 对齐。
--
-- 执行：mysql -u root -p < db/04_fix_menu_route_name.sql
-- 注意：db/03_seed.sql 会 DELETE 并重建菜单，重跑 seed 后需再次执行本脚本（幂等，可重复执行）。
-- ============================================================================

USE `shop`;

UPDATE `sys_menu`
SET `route_name` = 'MerchantItems', `update_time` = NOW()
WHERE `menu_id` = 3201
  AND `component` = 'mall/merchant/item/index';

UPDATE `sys_menu`
SET `route_name` = 'MerchantOrders', `update_time` = NOW()
WHERE `menu_id` = 3202
  AND `component` = 'mall/merchant/order/index';

-- 校验：应返回 2 行，route_name 分别为 MerchantItems / MerchantOrders
SELECT `menu_id`, `menu_name`, `path`, `component`, `route_name`
FROM `sys_menu`
WHERE `menu_id` IN (3201, 3202)
ORDER BY `menu_id`;

-- 校验：正常应为 0 行（若返回结果，说明仍有其他菜单 route_name 冲突）
SELECT `route_name`, COUNT(*) AS `cnt`
FROM `sys_menu`
WHERE `route_name` IS NOT NULL
  AND `route_name` <> ''
GROUP BY `route_name`
HAVING COUNT(*) > 1;
