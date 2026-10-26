-- ============================================================================
-- 萌宠优选 · 宠物商城系统  数据库脚本 02：业务表结构（pet_* 14 张）
-- 依据：需求文档 v2.0 §7（数据需求）、设计文档 v1.0 §6（数据库设计）
-- 数据库：shop（MySQL 8.0，utf8mb4 / utf8mb4_general_ci，InnoDB）
-- 注意：shop 已有若依 31 张系统表时，无需执行 01，直接执行本脚本与 03_seed.sql 即可
-- 执行顺序：01_base.sql → 02_pet_mall.sql → 03_seed.sql
-- 执行方式：mysql -uroot -p --default-character-set=utf8mb4 < db/02_pet_mall.sql
-- 可重复执行：是（先 DROP 再 CREATE；仅限演示/测试环境，生产变更必须走 ALTER 迁移）
-- 约定：金额 DECIMAL(10,2)；库存 INT + CHECK(stock>=0)；不建物理外键；引用完整性由应用层保证
-- ============================================================================
SET NAMES utf8mb4;
USE `shop`;

-- 按依赖逆序删除（本套表不建物理外键，顺序仅用于可读性与迁移安全）
DROP TABLE IF EXISTS `pet_payment_request`;
DROP TABLE IF EXISTS `pet_member_favorite`;
DROP TABLE IF EXISTS `pet_member_preference`;
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

-- ----------------------------------------------------------------------------
-- 1. 会员表 pet_member（E01 / C-10）
--    uk_username、uk_phone 作为注册唯一性约束；password 存 BCrypt 哈希
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_member` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '会员ID',
  `username`      VARCHAR(30)     NOT NULL                COMMENT '登录名，4-20位',
  `password`      VARCHAR(100)    NOT NULL                COMMENT 'BCrypt 哈希',
  `nickname`      VARCHAR(30)     NOT NULL                COMMENT '昵称',
  `phone`         VARCHAR(20)     DEFAULT NULL            COMMENT '手机号，接口脱敏',
  `avatar`        VARCHAR(255)    DEFAULT NULL            COMMENT '头像地址',
  `status`        TINYINT         NOT NULL DEFAULT 0      COMMENT '0正常 1禁用',
  `del_flag`      CHAR(1)         NOT NULL DEFAULT '0'    COMMENT '0存在 1删除',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_phone` (`phone`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='会员';

-- ----------------------------------------------------------------------------
-- 2. 宠物档案表 pet_member_pet（E02 / C-05）
--    档案驱动选购：species/age_stage/weight 为商品适配判定的数据源
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_member_pet` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '档案ID',
  `member_id`     BIGINT UNSIGNED NOT NULL                COMMENT '归属会员',
  `name`          VARCHAR(30)     NOT NULL                COMMENT '宠物名',
  `species`       VARCHAR(10)     NOT NULL                COMMENT 'CAT/DOG/SMALL（原设计 CHAR(2) 无法容纳 DOG/SMALL，已修正）',
  `breed`         VARCHAR(50)     DEFAULT NULL            COMMENT '品种',
  `birthday`      DATE            DEFAULT NULL            COMMENT '生日，用于推算月龄',
  `weight`        DECIMAL(5,2)    DEFAULT NULL            COMMENT '体重kg，0.1-100',
  `sterilized`    TINYINT         NOT NULL DEFAULT 0      COMMENT '是否绝育 0否 1是',
  `allergy_note`  VARCHAR(200)    DEFAULT NULL            COMMENT '过敏源/忌口',
  `status`        TINYINT         NOT NULL DEFAULT 0      COMMENT '0正常 1归档',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_member` (`member_id`),
  CONSTRAINT `chk_pet_weight` CHECK (`weight` IS NULL OR (`weight` >= 0.1 AND `weight` <= 100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='宠物档案';

-- ----------------------------------------------------------------------------
-- 3. 收货地址表 pet_address（E03 / C-07-01）
--    默认地址业务唯一（事务内先清 0 再置 1）；订单落快照，不受地址修改影响
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_address` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '地址ID',
  `member_id`     BIGINT UNSIGNED NOT NULL                COMMENT '归属会员',
  `receiver`      VARCHAR(30)     NOT NULL                COMMENT '收货人',
  `phone`         VARCHAR(20)     NOT NULL                COMMENT '联系电话',
  `province`      VARCHAR(50)     NOT NULL                COMMENT '省',
  `city`          VARCHAR(50)     NOT NULL                COMMENT '市',
  `district`      VARCHAR(50)     NOT NULL                COMMENT '区/县',
  `detail`        VARCHAR(200)    NOT NULL                COMMENT '详细地址',
  `is_default`    TINYINT         NOT NULL DEFAULT 0      COMMENT '0否 1默认',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_member` (`member_id`, `is_default`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='收货地址';

-- ----------------------------------------------------------------------------
-- 4. 分类表 pet_category（E04 / C-02）
--    两级分类：parent_id=0 为一级，商品挂二级分类
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_category` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类ID',
  `parent_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0      COMMENT '父级ID，0为一级',
  `name`          VARCHAR(50)     NOT NULL                COMMENT '分类名',
  `icon`          VARCHAR(255)    DEFAULT NULL            COMMENT '图标',
  `sort`          INT             NOT NULL DEFAULT 0      COMMENT '排序，越小越前',
  `pet_scope`     VARCHAR(20)     NOT NULL DEFAULT 'ALL'  COMMENT 'CAT/DOG/SMALL/ALL',
  `status`        TINYINT         NOT NULL DEFAULT 0      COMMENT '0正常 1停用',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_parent` (`parent_id`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='商品分类';

-- ----------------------------------------------------------------------------
-- 5. 商品表 pet_item（E05 / C-04 / A-01）
--    审核通过（audit_status=2）且上架（status=1）才对前台可见
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_item` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品ID',
  `category_id`       BIGINT UNSIGNED NOT NULL                COMMENT '二级分类',
  `merchant_id`       BIGINT UNSIGNED NOT NULL                COMMENT '归属商家',
  `title`             VARCHAR(100)    NOT NULL                COMMENT '标题',
  `subtitle`          VARCHAR(200)    DEFAULT NULL            COMMENT '卖点',
  `main_image`        VARCHAR(255)    NOT NULL                COMMENT '主图',
  `brand`             VARCHAR(50)     DEFAULT NULL            COMMENT '品牌（二期独立实体）',
  `pet_species`       VARCHAR(20)     NOT NULL                COMMENT 'CAT/DOG/SMALL/ALL',
  `age_stage`         VARCHAR(20)     NOT NULL                COMMENT 'JUNIOR/ADULT/SENIOR/ALL',
  `weight_range`      VARCHAR(20)     DEFAULT NULL            COMMENT '适用体重段，如 3-10',
  `price_min`         DECIMAL(10,2)   NOT NULL                COMMENT '最低SKU价（冗余）',
  `cost_price`        DECIMAL(10,2)   DEFAULT NULL            COMMENT '成本价（后台）',
  `support_subscribe` TINYINT         NOT NULL DEFAULT 0      COMMENT '二期：是否支持订阅',
  `is_prescription`   TINYINT         NOT NULL DEFAULT 0      COMMENT '二期：是否处方商品',
  `detail`            MEDIUMTEXT      DEFAULT NULL            COMMENT '详情富文本，XSS过滤后存储',
  `audit_status`      TINYINT         NOT NULL DEFAULT 0      COMMENT '0待审 1驳回 2通过',
  `status`            TINYINT         NOT NULL DEFAULT 0      COMMENT '0下架 1上架',
  `sales`             INT             NOT NULL DEFAULT 0      COMMENT '累计销量',
  `del_flag`          CHAR(1)         NOT NULL DEFAULT '0'    COMMENT '0存在 1删除',
  `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`       DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `audit_status`),
  KEY `idx_species_stage` (`pet_species`, `age_stage`),
  KEY `idx_sales` (`sales`),
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='商品SPU';

-- ----------------------------------------------------------------------------
-- 6. 规格表 pet_item_sku（E06 / A-01-02）
--    防超卖核心：stock + CHECK(stock>=0)，扣减使用条件 UPDATE ... WHERE stock>=qty
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_item_sku` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'SKU_ID',
  `item_id`       BIGINT UNSIGNED NOT NULL                COMMENT '所属商品',
  `spec_name`     VARCHAR(50)     NOT NULL                COMMENT '规格名，如 2kg装',
  `price`         DECIMAL(10,2)   NOT NULL                COMMENT '售价',
  `stock`         INT             NOT NULL DEFAULT 0      COMMENT '可售库存',
  `sku_code`      VARCHAR(50)     DEFAULT NULL            COMMENT 'SKU编码',
  `image`         VARCHAR(255)    DEFAULT NULL            COMMENT '规格图',
  `status`        TINYINT         NOT NULL DEFAULT 1      COMMENT '0停用 1启用',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_code` (`sku_code`),
  KEY `idx_item` (`item_id`),
  CONSTRAINT `chk_sku_price` CHECK (`price` > 0),
  CONSTRAINT `chk_sku_stock` CHECK (`stock` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='商品规格SKU';

-- ----------------------------------------------------------------------------
-- 7. 商品图片表 pet_item_image（E07）
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_item_image` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '图片ID',
  `item_id`       BIGINT UNSIGNED NOT NULL                COMMENT '所属商品',
  `url`           VARCHAR(255)    NOT NULL                COMMENT '图片地址',
  `sort`          INT             NOT NULL DEFAULT 0      COMMENT '排序',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_item` (`item_id`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='商品图片';

-- ----------------------------------------------------------------------------
-- 8. 审核留痕表 pet_item_audit（E13 / A-01-07）
--    只增不改：每次审核结论、审核人、理由均留痕
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_item_audit` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '留痕ID',
  `item_id`       BIGINT UNSIGNED NOT NULL                COMMENT '商品ID',
  `audit_status`  TINYINT         NOT NULL                COMMENT '1驳回 2通过',
  `auditor`       VARCHAR(50)     NOT NULL                COMMENT '审核人账号',
  `remark`        VARCHAR(500)    DEFAULT NULL            COMMENT '审核意见，驳回必填',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_item` (`item_id`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='商品审核留痕';

-- ----------------------------------------------------------------------------
-- 9. 购物车表 pet_cart_item（E08 / C-06）
--    uk_member_sku 保证同一会员同一 SKU 只有一行，加购走累加
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_cart_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '购物车行ID',
  `member_id`     BIGINT UNSIGNED NOT NULL                COMMENT '会员',
  `item_id`       BIGINT UNSIGNED NOT NULL                COMMENT '商品',
  `sku_id`        BIGINT UNSIGNED NOT NULL                COMMENT 'SKU',
  `quantity`      INT             NOT NULL DEFAULT 1      COMMENT '数量1-99',
  `checked`       TINYINT         NOT NULL DEFAULT 1      COMMENT '是否勾选',
  `pet_id`        BIGINT UNSIGNED DEFAULT NULL            COMMENT '标记为哪只宠物购买',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_member_sku` (`member_id`, `sku_id`),
  KEY `idx_member` (`member_id`),
  CONSTRAINT `chk_cart_qty` CHECK (`quantity` >= 1 AND `quantity` <= 99)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='购物车行';

-- ----------------------------------------------------------------------------
-- 10. 订单表 pet_order（E09 / C-07 / C-08）
--     状态 0-8 与 SRS 4.3.1 一致；uk_client_token 防重复提交；
--     (status,create_time) 支撑超时关单扫描；(member_id,status) 支撑订单六页签
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_order` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单ID',
  `order_no`          VARCHAR(32)     NOT NULL                COMMENT '订单号 PET+时间戳+4位随机',
  `member_id`         BIGINT UNSIGNED NOT NULL                COMMENT '下单会员',
  `merchant_id`       BIGINT UNSIGNED NOT NULL                COMMENT '商家',
  `total_amount`      DECIMAL(10,2)   NOT NULL                COMMENT '商品总额',
  `discount_amount`   DECIMAL(10,2)   NOT NULL DEFAULT 0.00   COMMENT '优惠总额（二期）',
  `freight`           DECIMAL(10,2)   NOT NULL DEFAULT 0.00   COMMENT '运费',
  `pay_amount`        DECIMAL(10,2)   NOT NULL                COMMENT '应付=总额+运费-优惠',
  `status`            TINYINT         NOT NULL DEFAULT 0      COMMENT '0待付款 1待审核 2待发货 3待收货 4已完成 5已取消 6已关闭 7售后中 8已退款',
  `receiver_snapshot` VARCHAR(1000)   NOT NULL                COMMENT '收货信息快照JSON',
  `pet_snapshot`      VARCHAR(500)    DEFAULT NULL            COMMENT '宠物标记快照JSON',
  `remark`            VARCHAR(200)    DEFAULT NULL            COMMENT '订单备注',
  `client_token`      VARCHAR(64)     DEFAULT NULL            COMMENT '前端幂等键',
  `expire_at`         DATETIME        NOT NULL                COMMENT '支付截止时间',
  `pay_time`          DATETIME        DEFAULT NULL            COMMENT '支付时间',
  `ship_time`         DATETIME        DEFAULT NULL            COMMENT '发货时间',
  `receive_time`      DATETIME        DEFAULT NULL            COMMENT '收货时间',
  `close_time`        DATETIME        DEFAULT NULL            COMMENT '关闭时间',
  `cancel_reason`     VARCHAR(200)    DEFAULT NULL            COMMENT '取消/关闭原因',
  `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`       DATETIME        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  UNIQUE KEY `uk_client_token` (`client_token`),
  KEY `idx_member_status` (`member_id`, `status`),
  KEY `idx_status_create` (`status`, `create_time`),
  KEY `idx_merchant` (`merchant_id`, `status`),
  CONSTRAINT `chk_order_amount` CHECK (`pay_amount` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='订单';

-- ----------------------------------------------------------------------------
-- 11. 订单明细表 pet_order_item（E10）
--     商品标题/规格/单价/图片/宠物均存快照，主数据变更不影响历史订单
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_order_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '明细ID',
  `order_id`      BIGINT UNSIGNED NOT NULL                COMMENT '订单ID',
  `item_id`       BIGINT UNSIGNED NOT NULL                COMMENT '商品ID',
  `sku_id`        BIGINT UNSIGNED NOT NULL                COMMENT 'SKU_ID',
  `title`         VARCHAR(100)    NOT NULL                COMMENT '商品标题快照',
  `spec`          VARCHAR(50)     NOT NULL                COMMENT '规格名快照',
  `price`         DECIMAL(10,2)   NOT NULL                COMMENT '下单单价',
  `quantity`      INT             NOT NULL                COMMENT '数量',
  `amount`        DECIMAL(10,2)   NOT NULL                COMMENT '行金额 = 单价*数量',
  `image`         VARCHAR(255)    DEFAULT NULL            COMMENT '图片快照',
  `pet_snapshot`  VARCHAR(200)    DEFAULT NULL            COMMENT '宠物标记快照（名称/物种）',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order` (`order_id`),
  KEY `idx_sku` (`sku_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='订单明细（快照）';

-- ----------------------------------------------------------------------------
-- 12. 支付记录表 pet_payment（E11 / C-07-10）
--     uk_idempotency_key 是回调幂等的唯一判据：重复回调命中唯一键即视为重放
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_payment` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `payment_no`       VARCHAR(32)     NOT NULL                COMMENT '支付单号',
  `order_no`         VARCHAR(32)     NOT NULL                COMMENT '订单号',
  `amount`           DECIMAL(10,2)   NOT NULL                COMMENT '支付金额，须等于订单应付',
  `channel`          VARCHAR(20)     NOT NULL                COMMENT 'WECHAT/ALIPAY/BALANCE',
  `status`           VARCHAR(20)     NOT NULL                COMMENT 'SUCCESS/FAIL/TIMEOUT',
  `idempotency_key`  VARCHAR(64)     NOT NULL                COMMENT '幂等键',
  `callback_time`    DATETIME        DEFAULT NULL            COMMENT '回调时间',
  `create_time`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`),
  UNIQUE KEY `uk_idempotency_key` (`idempotency_key`),
  KEY `idx_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='支付记录';

-- ----------------------------------------------------------------------------
-- 13. 库存流水表 pet_stock_log（E12 / B-01-02）
--     uk_sku_order_type 防重复扣减/重复回滚；ADJUST(order_no='') 承载初始库存，
--     支持对账：Σ change_qty = 当前库存
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_stock_log` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `sku_id`        BIGINT UNSIGNED NOT NULL                COMMENT 'SKU_ID',
  `order_no`      VARCHAR(32)     NOT NULL DEFAULT ''     COMMENT '关联订单号，调整为空的用空串',
  `type`          VARCHAR(20)     NOT NULL                COMMENT 'DEDUCT/ROLLBACK/ADJUST',
  `change_qty`    INT             NOT NULL                COMMENT '变更量，扣减为负',
  `before_qty`    INT             NOT NULL                COMMENT '变更前库存',
  `after_qty`     INT             NOT NULL                COMMENT '变更后库存',
  `operator`      VARCHAR(50)     DEFAULT NULL            COMMENT '操作人，自动任务为 system',
  `remark`        VARCHAR(200)    DEFAULT NULL            COMMENT '备注/来源单据',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_order_type` (`sku_id`, `order_no`, `type`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_sku` (`sku_id`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='库存流水';

-- ----------------------------------------------------------------------------
-- 14. 站内消息表 pet_message（E29 / C-13-04）
-- ----------------------------------------------------------------------------
CREATE TABLE `pet_message` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '消息ID',
  `member_id`     BIGINT UNSIGNED NOT NULL                COMMENT '接收会员',
  `type`          VARCHAR(20)     NOT NULL                COMMENT 'ORDER/AUDIT/REFUND/SYSTEM',
  `title`         VARCHAR(100)    NOT NULL                COMMENT '标题',
  `content`       VARCHAR(500)    NOT NULL                COMMENT '内容',
  `target_url`    VARCHAR(255)    DEFAULT NULL            COMMENT '跳转地址',
  `read_flag`     TINYINT         NOT NULL DEFAULT 0      COMMENT '0未读 1已读',
  `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_member_read` (`member_id`, `read_flag`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='站内消息';

-- ============================================================================
-- 表结构说明（与设计文档 §6.2.1 一一对应，共 14 张）
-- 1 pet_member       会员        主数据  uk_username / uk_phone
-- 2 pet_member_pet   宠物档案    主数据  索引 member_id
-- 3 pet_address      收货地址    主数据  索引 (member_id,is_default)
-- 4 pet_category     商品分类    主数据  索引 (parent_id,sort)
-- 5 pet_item         商品 SPU    主数据  idx_category_status / idx_species_stage / idx_sales / idx_merchant / idx_title
-- 6 pet_item_sku     规格 SKU    主数据  uk_sku_code / idx_item / chk_sku_price / chk_sku_stock
-- 7 pet_item_image   商品图片    主数据  索引 (item_id,sort)
-- 8 pet_item_audit   审核留痕    流水    索引 (item_id,create_time)
-- 9 pet_cart_item    购物车行    业务    uk_member_sku / chk_cart_qty
-- 10 pet_order       订单        交易    uk_order_no / uk_client_token / idx_member_status / idx_status_create / idx_merchant
-- 11 pet_order_item  订单明细    交易    索引 order_id / sku_id
-- 12 pet_payment     支付记录    交易    uk_payment_no / uk_idempotency_key / idx_order_no
-- 13 pet_stock_log   库存流水    流水    uk_sku_order_type / idx_sku / idx_order_no
-- 14 pet_message     站内消息    业务    索引 (member_id,read_flag,create_time)
-- ============================================================================
