-- ============================================================================
-- 萌宠优选 · 宠物商城系统  数据库脚本 03：初始化数据（seed）
-- 依据：需求文档 v2.0 §3.7 演示账号、§7.7 初始化数据要求；设计文档 v1.0 §6.8
-- 目标库：shop（后端 application-druid.yml 已指向 shop；需先执行 02_pet_mall.sql）
-- 执行顺序：01_base.sql → 02_pet_mall.sql → 03_seed.sql
-- 执行方式：mysql -uroot -p --default-character-set=utf8mb4 < db/03_seed.sql
-- 可重复执行：是（先 DELETE 演示数据再插入；仅演示/测试环境，会重置业务数据）
-- 演示账号（密码为 BCrypt 强度 10）：
--   admin     / admin123     后台超级管理员（由 01_base.sql 初始化）
--   merchant1 / merchant123  商家，sys_user.dept_id = merchant_id = 9001
--   member1   / member123    会员主演示（2 个宠物档案、2 个地址）
--   member2   / member123    会员越权隔离演示（1 个宠物档案、1 个地址）
--   reviewer  / reviewer123  最小权限审核员（仅 mall:item:audit、mall:audit:list）
-- 关键演示数据：库存 1 的 SKU 用于并发防超卖；库存 0 的 SKU 用于售罄演示；
--               1 张待付款订单（超时关单）、1 张已完成订单（详情/评价）
-- ============================================================================
SET NAMES utf8mb4;
USE `shop`;
SET @now = NOW();

-- ============================================================================
-- 0. 清理演示数据（按依赖逆序；保留若依系统内置数据，仅清理 mall 相关）
-- ============================================================================
DELETE FROM pet_message;
DELETE FROM pet_stock_log;
DELETE FROM pet_payment;
DELETE FROM pet_order_item;
DELETE FROM pet_order;
DELETE FROM pet_cart_item;
DELETE FROM pet_item_audit;
DELETE FROM pet_item_image;
DELETE FROM pet_item_sku;
DELETE FROM pet_item;
DELETE FROM pet_category;
DELETE FROM pet_address;
DELETE FROM pet_member_pet;
DELETE FROM pet_member;

DELETE FROM sys_user_role     WHERE user_id IN (3, 4);
DELETE FROM sys_user          WHERE user_name IN ('merchant1', 'reviewer');
DELETE FROM sys_role_menu     WHERE role_id IN (100, 101);
DELETE FROM sys_role          WHERE role_id IN (100, 101);
DELETE FROM sys_menu          WHERE menu_id BETWEEN 3000 AND 3299;
DELETE FROM sys_config        WHERE config_key LIKE 'mall.%';
DELETE FROM sys_dept          WHERE dept_id = 9001;

-- ============================================================================
-- 1. 后台账号与 RBAC（设计文档 §6.8 / §9.3）
-- ============================================================================

-- 1.1 商家部门：merchant_id 绑定约定 sys_user.dept_id = merchant_id = 9001
INSERT INTO sys_dept
  (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email,
   status, del_flag, create_by, create_time, update_by, update_time)
VALUES
  (9001, 100, '0,100', '萌宠优选商家', 1, '商家管理员', '13900009001',
   'merchant@petmall.local', '0', '0', 'admin', @now, '', NULL);

-- 1.2 后台账号：merchant1、reviewer（admin/ry 由 01_base.sql 初始化）
--     BCrypt 哈希对应：merchant123、reviewer123
INSERT INTO sys_user
  (user_id, dept_id, user_name, nick_name, user_type, email, phonenumber, sex,
   avatar, password, status, del_flag, login_ip, login_date, pwd_update_date,
   create_by, create_time, update_by, update_time, remark)
VALUES
  (3, 9001, 'merchant1', '宠物商家', '00', 'merchant@petmall.local', '13900009001', '0',
   '', '$2a$10$EeJLGYzEQQrCt22f4BVtWeLFKMsdhuhKR8BtRfwTIWwajlgOFgi2a', '0', '0', '',
   NULL, @now, 'admin', @now, '', NULL, '演示商家，merchant_id=9001'),
  (4, 105, 'reviewer', '审核员', '00', 'reviewer@petmall.local', '13900009002', '0',
   '', '$2a$10$nBW2VlwAOZXUv3WcNIorKOI8hxAf9SHb7xbBoJ3MNZIB2/oNmFphO', '0', '0', '',
   NULL, @now, 'admin', @now, '', NULL, '最小权限审核员，仅 mall:item:audit / mall:audit:list');

-- 1.3 角色：商家（role_key=merchant）、审核员（role_key=reviewer）
INSERT INTO sys_role
  (role_id, role_name, role_key, role_sort, data_scope, menu_check_strictly,
   dept_check_strictly, status, del_flag, create_by, create_time, update_by, update_time, remark)
VALUES
  (100, '商家', 'merchant', 3, '3', 1, 1, '0', '0', 'admin', @now, '', NULL,
   '商家角色：仅本人商品与本人订单（merchant_id 隔离）'),
  (101, '审核员', 'reviewer', 4, '1', 1, 1, '0', '0', 'admin', @now, '', NULL,
   '最小权限审核角色：mall:item:audit、mall:audit:list');

INSERT INTO sys_user_role (user_id, role_id) VALUES (3, 100), (4, 101);

-- 1.4 商城菜单与按钮权限（menu_id 3000-3299 为商城保留段）
--     目录：商城管理（后台治理）、商家中心（商家视角）
INSERT INTO sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
   is_frame, is_cache, menu_type, visible, status, perms, icon,
   create_by, create_time, update_by, update_time, remark)
VALUES
  (3000, '商城管理', 0, 5, 'mall', NULL, '', '', 1, 0, 'M', '0', '0', '', 'shopping', 'admin', @now, '', NULL, '商城后台治理目录'),
  (3001, '工作台',   3000, 1, 'dashboard',  'mall/dashboard/index', '', '', 1, 0, 'C', '0', '0', 'mall:dashboard:view', 'dashboard', 'admin', @now, '', NULL, '数据概览'),
  (3002, '商品管理', 3000, 2, 'items',      'mall/item/index',      '', '', 1, 0, 'C', '0', '0', 'mall:item:list',      'goods',     'admin', @now, '', NULL, '商品列表与编辑'),
  (3003, '商品审核', 3000, 3, 'audit',      'mall/audit/index',     '', '', 1, 0, 'C', '0', '0', 'mall:item:audit',     'checkbox',  'admin', @now, '', NULL, '商品审核队列'),
  (3004, '类目管理', 3000, 4, 'categories', 'mall/category/index',  '', '', 1, 0, 'C', '0', '0', 'mall:category:list',  'tree',      'admin', @now, '', NULL, '两级分类管理'),
  (3005, '订单管理', 3000, 5, 'orders',     'mall/order/index',     '', '', 1, 0, 'C', '0', '0', 'mall:order:list',     'money',     'admin', @now, '', NULL, '全量订单与发货'),
  (3006, '会员管理', 3000, 6, 'members',    'mall/member/index',    '', '', 1, 0, 'C', '0', '0', 'mall:member:list',    'peoples',   'admin', @now, '', NULL, '会员列表与禁用'),
  (3007, '库存总览', 3000, 7, 'stock',      'mall/stock/index',     '', '', 1, 0, 'C', '0', '0', 'mall:stock:list',     'chart',     'admin', @now, '', NULL, '库存与流水'),
  (3008, '审计日志', 3000, 8, 'audit-log',  'mall/auditlog/index',  '', '', 1, 0, 'C', '0', '0', 'mall:audit:list',     'log',       'admin', @now, '', NULL, '操作审计查询'),

  (3010, '商品新增',     3002, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:item:add',           '#', 'admin', @now, '', NULL, ''),
  (3011, '商品修改',     3002, 2, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:item:edit',          '#', 'admin', @now, '', NULL, ''),
  (3012, '商品上下架',   3002, 3, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:item:status',        '#', 'admin', @now, '', NULL, ''),
  (3013, '商品审核',     3003, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:item:audit',         '#', 'admin', @now, '', NULL, ''),
  (3014, '类目新增',     3004, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:category:add',       '#', 'admin', @now, '', NULL, ''),
  (3015, '类目修改',     3004, 2, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:category:edit',      '#', 'admin', @now, '', NULL, ''),
  (3016, '类目删除',     3004, 3, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:category:remove',    '#', 'admin', @now, '', NULL, ''),
  (3017, '订单发货',     3005, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:order:ship',         '#', 'admin', @now, '', NULL, ''),
  (3018, '会员禁用/启用', 3006, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:member:status',      '#', 'admin', @now, '', NULL, ''),
  (3019, '手动触发关单', 3001, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:job:trigger',        '#', 'admin', @now, '', NULL, '仅 dev/test 环境显示'),

  (3200, '商家中心', 0, 6, 'merchant', NULL, '', '', 1, 0, 'M', '0', '0', '', 'business', 'admin', @now, '', NULL, '商家视角目录'),
  (3201, '我的商品', 3200, 1, 'items',  'mall/merchant/item/index',  '', '', 1, 0, 'C', '0', '0', 'mall:merchant:item:list',  'goods', 'admin', @now, '', NULL, '仅本人商品'),
  (3202, '我的订单', 3200, 2, 'orders', 'mall/merchant/order/index', '', '', 1, 0, 'C', '0', '0', 'mall:merchant:order:list', 'money', 'admin', @now, '', NULL, '仅本人商品相关订单'),

  (3210, '商品新增',   3201, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:merchant:item:add',    '#', 'admin', @now, '', NULL, ''),
  (3211, '商品修改',   3201, 2, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:merchant:item:edit',   '#', 'admin', @now, '', NULL, ''),
  (3212, '商品上下架', 3201, 3, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:merchant:item:status', '#', 'admin', @now, '', NULL, ''),
  (3213, '订单发货',   3202, 1, '', '', '', '', 1, 0, 'F', '0', '0', 'mall:merchant:order:ship',  '#', 'admin', @now, '', NULL, '');

-- 1.5 角色—菜单授权
--     商家：商家中心 + 我的商品/我的订单 + 按钮
INSERT INTO sys_role_menu (role_id, menu_id) VALUES
  (100, 3200), (100, 3201), (100, 3202),
  (100, 3210), (100, 3211), (100, 3212), (100, 3213);
--     审核员：商城管理目录 + 商品审核 + 审核按钮 + 审计日志
INSERT INTO sys_role_menu (role_id, menu_id) VALUES
  (101, 3000), (101, 3003), (101, 3013), (101, 3008);

-- ============================================================================
-- 2. 系统参数（设计文档 §6.8、附录 C：8 个 mall.* 配置键）
-- ============================================================================
INSERT INTO sys_config
  (config_id, config_name, config_key, config_value, config_type,
   create_by, create_time, update_by, update_time, remark)
VALUES
  (100, '订单-支付超时分钟数',     'mall.pay-timeout-minutes',       '15',    'Y', 'admin', @now, '', NULL, '待付款订单超时关单时限，演示可设为 1-5 分钟'),
  (101, '订单-自动确认收货天数',   'mall.auto-confirm-days',         '10',    'Y', 'admin', @now, '', NULL, '发货后自动确认收货天数，3-30 可配'),
  (102, '购物车-单会员SKU上限',    'mall.cart-max-sku',              '200',   'Y', 'admin', @now, '', NULL, '单会员购物车最大 SKU 行数'),
  (103, '会员-收货地址上限',       'mall.address-max',               '20',    'Y', 'admin', @now, '', NULL, '单会员最大收货地址数'),
  (104, '会员-宠物档案上限',       'mall.pet-max',                   '5',     'Y', 'admin', @now, '', NULL, '单会员最大宠物档案数，一期 5 只'),
  (105, '商品-单SKU单次限购',      'mall.buy-limit-default',         '99',    'Y', 'admin', @now, '', NULL, '单 SKU 单次最大购买数量'),
  (106, '订单-包邮门槛（元）',     'mall.freight-free-threshold',    '99.00', 'Y', 'admin', @now, '', NULL, '商品总额达到该值免运费'),
  (107, '订单-未达门槛运费（元）', 'mall.freight-fee',               '10.00', 'Y', 'admin', @now, '', NULL, '未达包邮门槛时收取的运费');

-- ============================================================================
-- 3. 会员与宠物档案（需求 §7.7：2 会员 + 3 宠物档案）
-- ============================================================================
-- member1/member2 密码均为 member123（不同盐值哈希）
INSERT INTO pet_member
  (id, username, password, nickname, phone, avatar, status, del_flag, create_time, update_time)
VALUES
  (1001, 'member1', '$2a$10$jbQ4Qqb0Qh2t863qICy4L.nchwSmJZWF7PqEFO6/xGGybJIcEj22O',
   '奶糖爸爸', '13800138001', '/profile/mall/avatars/member1.png', 0, '0',
   DATE_SUB(@now, INTERVAL 30 DAY), @now),
  (1002, 'member2', '$2a$10$PSCrHEqp.BP1pAGLkxkFue8zgYUSO.ewmQ2HRp3Eo/gScOaBJ1fIi',
   '橘座铲屎官', '13800138002', '/profile/mall/avatars/member2.png', 0, '0',
   DATE_SUB(@now, INTERVAL 25 DAY), @now);

-- 3.1 宠物档案：member1 幼猫 + 成犬；member2 成猫
INSERT INTO pet_member_pet
  (id, member_id, name, species, breed, birthday, weight, sterilized, allergy_note,
   status, create_time, update_time)
VALUES
  (1, 1001, '奶糖', 'CAT', '英国短毛猫', DATE_SUB(CURDATE(), INTERVAL 8 MONTH), 3.60, 0,
   '对谷物轻微过敏', 0, DATE_SUB(@now, INTERVAL 28 DAY), @now),
  (2, 1001, '豆包', 'DOG', '金毛寻回犬', DATE_SUB(CURDATE(), INTERVAL 3 YEAR), 28.50, 1,
   NULL, 0, DATE_SUB(@now, INTERVAL 26 DAY), @now),
  (3, 1002, '橘子', 'CAT', '中华田园猫', DATE_SUB(CURDATE(), INTERVAL 2 YEAR), 4.20, 1,
   NULL, 0, DATE_SUB(@now, INTERVAL 20 DAY), @now);

-- 3.2 收货地址：member1 两个（含默认）、member2 一个
INSERT INTO pet_address
  (id, member_id, receiver, phone, province, city, district, detail, is_default,
   create_time, update_time)
VALUES
  (1, 1001, '张小明', '13800138001', '广东省', '深圳市', '南山区', '科技园南路88号3栋1201', 1,
   DATE_SUB(@now, INTERVAL 28 DAY), @now),
  (2, 1001, '张小明', '13800138001', '广东省', '广州市', '天河区', '体育西路100号2203', 0,
   DATE_SUB(@now, INTERVAL 20 DAY), @now),
  (3, 1002, '李小红', '13800138002', '浙江省', '杭州市', '西湖区', '文三路200号5幢602', 1,
   DATE_SUB(@now, INTERVAL 18 DAY), @now);

-- ============================================================================
-- 4. 分类（需求 §7.7：8 个 = 4 个一级 + 4 个二级）
-- ============================================================================
INSERT INTO pet_category
  (id, parent_id, name, icon, sort, pet_scope, status, create_time, update_time)
VALUES
  (1,  0, '猫粮',         '/profile/mall/icons/cat-food.png',  1, 'CAT', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (2,  0, '狗粮',         '/profile/mall/icons/dog-food.png',  2, 'DOG', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (3,  0, '宠物零食',     '/profile/mall/icons/snack.png',     3, 'ALL', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (4,  0, '宠物用品与保健', '/profile/mall/icons/supply.png',   4, 'ALL', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (11, 1, '猫主粮',       '/profile/mall/icons/cat-food.png',  1, 'CAT', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (12, 2, '犬主粮',       '/profile/mall/icons/dog-food.png',  1, 'DOG', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (13, 3, '零食罐头',     '/profile/mall/icons/snack.png',     1, 'ALL', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now),
  (14, 4, '清洁与保健',   '/profile/mall/icons/supply.png',    1, 'ALL', 0, DATE_SUB(@now, INTERVAL 60 DAY), @now);

-- ============================================================================
-- 5. 商品 SPU（需求 §7.7：12 个，覆盖猫/犬/小宠、幼年/成体/老年、不同价格段；
--    1 个待审 item 11、1 个驳回 item 12）
-- ============================================================================
INSERT INTO pet_item
  (id, category_id, merchant_id, title, subtitle, main_image, brand, pet_species,
   age_stage, weight_range, price_min, cost_price, support_subscribe, is_prescription,
   detail, audit_status, status, sales, del_flag, create_time, update_time)
VALUES
  (1, 11, 9001, '皇家幼猫粮 K36 2kg', '幼猫专用配方，呵护肠胃',
   '/profile/mall/items/item-01.jpg', '皇家', 'CAT', 'JUNIOR', '0.5-5', 89.00, 62.00, 0, 0,
   '<p>适用于 4-12 月龄幼猫，添加益生元与 DHA，帮助消化与脑部发育。</p>', 2, 1, 320, '0',
   DATE_SUB(@now, INTERVAL 20 DAY), @now),
  (2, 11, 9001, '渴望成猫无谷鸡肉猫粮 1.8kg', '高蛋白无谷配方',
   '/profile/mall/items/item-02.jpg', '渴望', 'CAT', 'ADULT', '3-10', 219.00, 165.00, 0, 0,
   '<p>85% 动物性原料，无谷物添加，适合成猫日常主食。</p>', 2, 1, 128, '0',
   DATE_SUB(@now, INTERVAL 19 DAY), @now),
  (3, 11, 9001, '网易严选全价猫粮 1.8kg', '全阶段全价猫粮',
   '/profile/mall/items/item-03.jpg', '网易严选', 'CAT', 'ALL', '0-15', 109.00, 86.00, 0, 0,
   '<p>全阶段全价猫粮，粗蛋白≥36%，适合多猫家庭。</p>', 2, 1, 45, '0',
   DATE_SUB(@now, INTERVAL 18 DAY), @now),
  (4, 12, 9001, '皇家幼犬奶糕 1kg', '断奶期幼犬专用',
   '/profile/mall/items/item-04.jpg', '皇家', 'DOG', 'JUNIOR', '0.5-10', 128.00, 96.00, 0, 0,
   '<p>断奶期至 2 月龄幼犬过渡粮，易泡软、易消化。</p>', 2, 1, 260, '0',
   DATE_SUB(@now, INTERVAL 17 DAY), @now),
  (5, 12, 9001, '冠能成犬粮 2.5kg', '成犬营养均衡',
   '/profile/mall/items/item-05.jpg', '冠能', 'DOG', 'ADULT', '5-25', 159.00, 118.00, 0, 0,
   '<p>优质蛋白与关节营养素，适合中大型成犬。</p>', 2, 1, 180, '0',
   DATE_SUB(@now, INTERVAL 16 DAY), @now),
  (6, 12, 9001, '伯纳天纯老年犬粮 2kg', '老年犬关节呵护',
   '/profile/mall/items/item-06.jpg', '伯纳天纯', 'DOG', 'SENIOR', '3-20', 139.00, 102.00, 0, 0,
   '<p>低脂配方，添加葡萄糖胺与软骨素，呵护老年犬关节。</p>', 2, 1, 96, '0',
   DATE_SUB(@now, INTERVAL 15 DAY), @now),
  (7, 13, 9001, '麦富迪猫罐头 85g×6', '成猫湿粮补水',
   '/profile/mall/items/item-07.jpg', '麦富迪', 'CAT', 'ADULT', NULL, 39.90, 28.00, 0, 0,
   '<p>鲜肉湿粮，补水适口，可拌粮喂食。</p>', 2, 1, 520, '0',
   DATE_SUB(@now, INTERVAL 14 DAY), @now),
  (8, 13, 9001, '顽皮鸡肉条 100g', '训练奖励零食',
   '/profile/mall/items/item-08.jpg', '顽皮', 'DOG', 'ALL', NULL, 19.90, 13.50, 0, 0,
   '<p>鸡胸肉低温烘焙，适合训练奖励与日常互动。</p>', 2, 1, 610, '0',
   DATE_SUB(@now, INTERVAL 13 DAY), @now),
  (9, 13, 9001, '提摩西草 500g', '小宠磨牙主食草',
   '/profile/mall/items/item-09.jpg', '兔博士', 'SMALL', 'ALL', NULL, 29.90, 20.00, 0, 0,
   '<p>一割提摩西草，适合兔、豚鼠、龙猫日常磨牙。</p>', 2, 1, 88, '0',
   DATE_SUB(@now, INTERVAL 12 DAY), @now),
  (10, 14, 9001, '怡亲豆腐猫砂 6L', '低粉尘可冲厕',
   '/profile/mall/items/item-10.jpg', '怡亲', 'ALL', 'ALL', NULL, 25.90, 17.00, 0, 0,
   '<p>豆腐渣原料，结团快、粉尘低，可少量冲厕。</p>', 2, 1, 430, '0',
   DATE_SUB(@now, INTERVAL 11 DAY), @now),
  (11, 14, 9001, '小佩智能饮水机 2L', '循环过滤静音',
   '/profile/mall/items/item-11.jpg', '小佩', 'ALL', 'ALL', NULL, 199.00, 150.00, 0, 0,
   '<p>四重过滤循环水，静音水泵，适合猫犬日常饮水。</p>', 0, 0, 0, '0',
   DATE_SUB(@now, INTERVAL 2 DAY), @now),
  (12, 14, 9001, '麦德氏猫用化毛膏 60g', '帮助排毛球',
   '/profile/mall/items/item-12.jpg', '麦德氏', 'CAT', 'ADULT', NULL, 45.00, 32.00, 0, 0,
   '<p>帮助猫咪排出毛球，改善食欲。</p>', 1, 0, 0, '0',
   DATE_SUB(@now, INTERVAL 6 DAY), @now);

-- ============================================================================
-- 6. 商品 SKU（需求 §7.7：24 个；至少 1 个 stock=1 用于防超卖、1 个 stock=0 售罄）
--    SKU 1/3/14 的库存为演示订单扣减后的当前值（初始值见库存流水 ADJUST）
-- ============================================================================
INSERT INTO pet_item_sku
  (id, item_id, spec_name, price, stock, sku_code, image, status, create_time, update_time)
VALUES
  (1,  1,  '2kg装',   89.00,  120, 'CAT-ROYAL-K36-2KG',  '/profile/mall/skus/sku-01.jpg', 1, DATE_SUB(@now, INTERVAL 20 DAY), @now),
  (2,  1,  '4kg装',   169.00, 80,  'CAT-ROYAL-K36-4KG',  '/profile/mall/skus/sku-02.jpg', 1, DATE_SUB(@now, INTERVAL 20 DAY), @now),
  (3,  2,  '1.8kg装', 219.00, 60,  'CAT-ORIJEN-18',      '/profile/mall/skus/sku-03.jpg', 1, DATE_SUB(@now, INTERVAL 19 DAY), @now),
  (4,  2,  '5.4kg装', 559.00, 30,  'CAT-ORIJEN-54',      '/profile/mall/skus/sku-04.jpg', 1, DATE_SUB(@now, INTERVAL 19 DAY), @now),
  (5,  3,  '1.8kg装', 109.00, 1,   'CAT-NETEASE-18',     '/profile/mall/skus/sku-05.jpg', 1, DATE_SUB(@now, INTERVAL 18 DAY), @now),
  (6,  4,  '1kg装',   128.00, 90,  'DOG-ROYAL-1KG',      '/profile/mall/skus/sku-06.jpg', 1, DATE_SUB(@now, INTERVAL 17 DAY), @now),
  (7,  4,  '3kg装',   328.00, 40,  'DOG-ROYAL-3KG',      '/profile/mall/skus/sku-07.jpg', 1, DATE_SUB(@now, INTERVAL 17 DAY), @now),
  (8,  4,  '10kg装',  899.00, 15,  'DOG-ROYAL-10KG',     '/profile/mall/skus/sku-08.jpg', 1, DATE_SUB(@now, INTERVAL 17 DAY), @now),
  (9,  5,  '2.5kg装', 159.00, 70,  'DOG-PROPLAN-25',     '/profile/mall/skus/sku-09.jpg', 1, DATE_SUB(@now, INTERVAL 16 DAY), @now),
  (10, 5,  '7kg装',   399.00, 35,  'DOG-PROPLAN-7',      '/profile/mall/skus/sku-10.jpg', 1, DATE_SUB(@now, INTERVAL 16 DAY), @now),
  (11, 5,  '12kg装',  629.00, 20,  'DOG-PROPLAN-12',     '/profile/mall/skus/sku-11.jpg', 1, DATE_SUB(@now, INTERVAL 16 DAY), @now),
  (12, 6,  '2kg装',   139.00, 55,  'DOG-BNTC-2',         '/profile/mall/skus/sku-12.jpg', 1, DATE_SUB(@now, INTERVAL 15 DAY), @now),
  (13, 6,  '6kg装',   369.00, 25,  'DOG-BNTC-6',         '/profile/mall/skus/sku-13.jpg', 1, DATE_SUB(@now, INTERVAL 15 DAY), @now),
  (14, 7,  '85g×6罐', 39.90,  80,  'CAT-MFD-6',          '/profile/mall/skus/sku-14.jpg', 1, DATE_SUB(@now, INTERVAL 14 DAY), @now),
  (15, 7,  '85g×12罐',69.90,  45,  'CAT-MFD-12',         '/profile/mall/skus/sku-15.jpg', 1, DATE_SUB(@now, INTERVAL 14 DAY), @now),
  (16, 8,  '100g装',  19.90,  0,   'DOG-WP-100',         '/profile/mall/skus/sku-16.jpg', 1, DATE_SUB(@now, INTERVAL 13 DAY), @now),
  (17, 8,  '200g装',  35.90,  50,  'DOG-WP-200',         '/profile/mall/skus/sku-17.jpg', 1, DATE_SUB(@now, INTERVAL 13 DAY), @now),
  (18, 9,  '500g装',  29.90,  66,  'SMALL-TIMO-500',     '/profile/mall/skus/sku-18.jpg', 1, DATE_SUB(@now, INTERVAL 12 DAY), @now),
  (19, 9,  '1kg装',   49.90,  32,  'SMALL-TIMO-1K',      '/profile/mall/skus/sku-19.jpg', 1, DATE_SUB(@now, INTERVAL 12 DAY), @now),
  (20, 10, '6L装',    25.90,  200, 'CAT-LITTER-6L',      '/profile/mall/skus/sku-20.jpg', 1, DATE_SUB(@now, INTERVAL 11 DAY), @now),
  (21, 10, '12L装',   45.90,  120, 'CAT-LITTER-12L',     '/profile/mall/skus/sku-21.jpg', 1, DATE_SUB(@now, INTERVAL 11 DAY), @now),
  (22, 11, '2L标准版',199.00, 18,  'ALL-FOUNTAIN-2L',    '/profile/mall/skus/sku-22.jpg', 1, DATE_SUB(@now, INTERVAL 2 DAY),  @now),
  (23, 12, '60g装',   45.00,  0,   'CAT-HAIRBALL-60',    '/profile/mall/skus/sku-23.jpg', 1, DATE_SUB(@now, INTERVAL 6 DAY),  @now),
  (24, 12, '120g装',  79.00,  30,  'CAT-HAIRBALL-120',   '/profile/mall/skus/sku-24.jpg', 1, DATE_SUB(@now, INTERVAL 6 DAY),  @now);

-- 6.1 商品图片（占位路径，后续由后台上传替换）
INSERT INTO pet_item_image (id, item_id, url, sort, create_time) VALUES
  (1,  1,  '/profile/mall/items/item-01.jpg', 0, DATE_SUB(@now, INTERVAL 20 DAY)),
  (2,  2,  '/profile/mall/items/item-02.jpg', 0, DATE_SUB(@now, INTERVAL 19 DAY)),
  (3,  3,  '/profile/mall/items/item-03.jpg', 0, DATE_SUB(@now, INTERVAL 18 DAY)),
  (4,  4,  '/profile/mall/items/item-04.jpg', 0, DATE_SUB(@now, INTERVAL 17 DAY)),
  (5,  5,  '/profile/mall/items/item-05.jpg', 0, DATE_SUB(@now, INTERVAL 16 DAY)),
  (6,  6,  '/profile/mall/items/item-06.jpg', 0, DATE_SUB(@now, INTERVAL 15 DAY)),
  (7,  7,  '/profile/mall/items/item-07.jpg', 0, DATE_SUB(@now, INTERVAL 14 DAY)),
  (8,  8,  '/profile/mall/items/item-08.jpg', 0, DATE_SUB(@now, INTERVAL 13 DAY)),
  (9,  9,  '/profile/mall/items/item-09.jpg', 0, DATE_SUB(@now, INTERVAL 12 DAY)),
  (10, 10, '/profile/mall/items/item-10.jpg', 0, DATE_SUB(@now, INTERVAL 11 DAY)),
  (11, 11, '/profile/mall/items/item-11.jpg', 0, DATE_SUB(@now, INTERVAL 2 DAY)),
  (12, 12, '/profile/mall/items/item-12.jpg', 0, DATE_SUB(@now, INTERVAL 6 DAY));

-- 6.2 审核留痕（items 1-10 通过、item 12 驳回；item 11 待审无留痕）
INSERT INTO pet_item_audit (id, item_id, audit_status, auditor, remark, create_time) VALUES
  (1,  1,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 15 DAY)),
  (2,  2,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 15 DAY)),
  (3,  3,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 15 DAY)),
  (4,  4,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 14 DAY)),
  (5,  5,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 14 DAY)),
  (6,  6,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 13 DAY)),
  (7,  7,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 13 DAY)),
  (8,  8,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 12 DAY)),
  (9,  9,  2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 12 DAY)),
  (10, 10, 2, 'reviewer', '资质与检测报告齐全，审核通过', DATE_SUB(@now, INTERVAL 11 DAY)),
  (11, 12, 1, 'reviewer', '缺少生产许可证信息，请补充后重新提交', DATE_SUB(@now, INTERVAL 5 DAY));

-- ============================================================================
-- 7. 演示订单（需求 §7.7：1 张待付款 + 1 张已完成）
--    订单 A：待付款（status=0），用于超时关单与库存回滚演示
--    订单 B：已完成（status=4），用于订单详情/评价演示
-- ============================================================================

-- 7.1 订单主表
INSERT INTO pet_order
  (id, order_no, member_id, merchant_id, total_amount, discount_amount, freight,
   pay_amount, status, receiver_snapshot, pet_snapshot, remark, client_token,
   expire_at, pay_time, ship_time, receive_time, close_time, cancel_reason,
   create_time, update_time)
VALUES
  (1, 'PET202610190900000001', 1001, 9001, 89.00, 0.00, 10.00, 99.00, 0,
   '{"receiver":"张小明","phone":"13800138001","province":"广东省","city":"深圳市","district":"南山区","detail":"科技园南路88号3栋1201","postcode":"518000"}',
   '[{"id":1,"name":"奶糖","species":"CAT"}]',
   '演示订单：待付款，可演示超时关单与库存回滚', 'seed-client-token-0001',
   DATE_ADD(@now, INTERVAL 10 MINUTE), NULL, NULL, NULL, NULL, NULL,
   DATE_SUB(@now, INTERVAL 5 MINUTE), @now),
  (2, 'PET202610160900000002', 1001, 9001, 298.80, 0.00, 0.00, 298.80, 4,
   '{"receiver":"张小明","phone":"13800138001","province":"广东省","city":"深圳市","district":"南山区","detail":"科技园南路88号3栋1201","postcode":"518000"}',
   '[{"id":1,"name":"奶糖","species":"CAT"}]',
   '演示订单：已完成，可查看详情与物流时间线', 'seed-client-token-0002',
   DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 15 MINUTE),
   DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 1 MINUTE),
   DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 1 DAY),
   DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 2 DAY),
   NULL, NULL,
   DATE_SUB(@now, INTERVAL 3 DAY), @now);

-- 7.2 订单明细（商品快照，金额：订单 A 89.00；订单 B 219.00 + 39.90×2 = 298.80）
INSERT INTO pet_order_item
  (id, order_id, item_id, sku_id, title, spec, price, quantity, amount, image,
   pet_snapshot, create_time)
VALUES
  (1, 1, 1, 1, '皇家幼猫粮 K36 2kg', '2kg装', 89.00, 1, 89.00,
   '/profile/mall/items/item-01.jpg', '{"id":1,"name":"奶糖","species":"CAT"}',
   DATE_SUB(@now, INTERVAL 5 MINUTE)),
  (2, 2, 2, 3, '渴望成猫无谷鸡肉猫粮 1.8kg', '1.8kg装', 219.00, 1, 219.00,
   '/profile/mall/items/item-02.jpg', '{"id":1,"name":"奶糖","species":"CAT"}',
   DATE_SUB(@now, INTERVAL 3 DAY)),
  (3, 2, 7, 14, '麦富迪猫罐头 85g×6', '85g×6罐', 39.90, 2, 79.80,
   '/profile/mall/items/item-07.jpg', '{"id":1,"name":"奶糖","species":"CAT"}',
   DATE_SUB(@now, INTERVAL 3 DAY));

-- 7.3 支付记录（订单 B 支付成功，幂等键唯一；订单 A 未支付无支付记录）
INSERT INTO pet_payment
  (id, payment_no, order_no, amount, channel, status, idempotency_key,
   callback_time, create_time)
VALUES
  (1, 'PAY202610160900000002', 'PET202610160900000002', 298.80, 'WECHAT', 'SUCCESS',
   'seed-order-0002-pay-0001', DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 1 MINUTE),
   DATE_ADD(DATE_SUB(@now, INTERVAL 3 DAY), INTERVAL 1 MINUTE));

-- ============================================================================
-- 8. 库存流水（对账约定：每个 SKU 一条 ADJUST 作为初始库存，Σchange_qty = 当前库存）
-- ============================================================================
-- 8.1 初始库存（24 条 ADJUST；SKU 1/3/14 的初始值 = 当前库存 + 演示订单扣减量）
INSERT INTO pet_stock_log
  (id, sku_id, order_no, type, change_qty, before_qty, after_qty, operator, remark, create_time)
VALUES
  (1,  1,  '', 'ADJUST', 121, 0, 121, 'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (2,  2,  '', 'ADJUST', 80,  0, 80,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (3,  3,  '', 'ADJUST', 61,  0, 61,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (4,  4,  '', 'ADJUST', 30,  0, 30,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (5,  5,  '', 'ADJUST', 1,   0, 1,   'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (6,  6,  '', 'ADJUST', 90,  0, 90,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (7,  7,  '', 'ADJUST', 40,  0, 40,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (8,  8,  '', 'ADJUST', 15,  0, 15,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (9,  9,  '', 'ADJUST', 70,  0, 70,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (10, 10, '', 'ADJUST', 35,  0, 35,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (11, 11, '', 'ADJUST', 20,  0, 20,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (12, 12, '', 'ADJUST', 55,  0, 55,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (13, 13, '', 'ADJUST', 25,  0, 25,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (14, 14, '', 'ADJUST', 82,  0, 82,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (15, 15, '', 'ADJUST', 45,  0, 45,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (16, 16, '', 'ADJUST', 0,   0, 0,   'seed', '初始化库存（售罄演示）', DATE_SUB(@now, INTERVAL 30 DAY)),
  (17, 17, '', 'ADJUST', 50,  0, 50,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (18, 18, '', 'ADJUST', 66,  0, 66,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (19, 19, '', 'ADJUST', 32,  0, 32,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (20, 20, '', 'ADJUST', 200, 0, 200, 'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (21, 21, '', 'ADJUST', 120, 0, 120, 'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (22, 22, '', 'ADJUST', 18,  0, 18,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY)),
  (23, 23, '', 'ADJUST', 0,   0, 0,   'seed', '初始化库存（驳回商品）', DATE_SUB(@now, INTERVAL 30 DAY)),
  (24, 24, '', 'ADJUST', 30,  0, 30,  'seed', '初始化库存', DATE_SUB(@now, INTERVAL 30 DAY));

-- 8.2 演示订单扣减流水（订单 A：SKU 1 ×1；订单 B：SKU 3 ×1、SKU 14 ×2）
INSERT INTO pet_stock_log
  (id, sku_id, order_no, type, change_qty, before_qty, after_qty, operator, remark, create_time)
VALUES
  (25, 1,  'PET202610190900000001', 'DEDUCT', -1, 121, 120, 'system', '下单原子扣减', DATE_SUB(@now, INTERVAL 5 MINUTE)),
  (26, 3,  'PET202610160900000002', 'DEDUCT', -1, 61,  60,  'system', '下单原子扣减', DATE_SUB(@now, INTERVAL 3 DAY)),
  (27, 14, 'PET202610160900000002', 'DEDUCT', -2, 82,  80,  'system', '下单原子扣减', DATE_SUB(@now, INTERVAL 3 DAY));

-- ============================================================================
-- 9. 可选演示数据：购物车 2 行、站内消息 2 条（便于购物车与消息中心联调）
-- ============================================================================
INSERT INTO pet_cart_item
  (id, member_id, item_id, sku_id, quantity, checked, pet_id, create_time, update_time)
VALUES
  (1, 1001, 1, 2,  1, 1, 1,    DATE_SUB(@now, INTERVAL 2 HOUR), @now),
  (2, 1001, 10, 20, 2, 0, NULL, DATE_SUB(@now, INTERVAL 1 HOUR), @now);

INSERT INTO pet_message
  (id, member_id, type, title, content, target_url, read_flag, create_time)
VALUES
  (1, 1001, 'ORDER', '订单已发货', '您的订单 PET202610160900000002 已发货，请留意物流信息。',
   '/orders/PET202610160900000002', 1, DATE_SUB(@now, INTERVAL 1 DAY)),
  (2, 1001, 'ORDER', '订单已完成', '您的订单 PET202610160900000002 已确认收货，欢迎评价。',
   '/orders/PET202610160900000002', 0, DATE_SUB(@now, INTERVAL 6 HOUR));

-- ============================================================================
-- seed 结束。核对口径（与需求 §7.7 一致）：
--   会员 2 / 宠物档案 3 / 地址 3 / 分类 8（4+4）/ 商品 12（待审 1、驳回 1）
--   SKU 24（库存 1 的 1 个、库存 0 的 2 个）/ 订单 2（待付款 1、已完成 1）
--   支付记录 1 / 库存流水 27（24 ADJUST + 3 DEDUCT）/ 后台角色 2 / 商城菜单 26
--   系统参数 8 / 购物车 2 / 站内消息 2 / 审核留痕 11
-- ============================================================================
