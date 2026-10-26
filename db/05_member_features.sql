-- Additive, repeatable upgrade. Existing members, orders and inventory are preserved.
SET NAMES utf8mb4;
CREATE TABLE IF NOT EXISTS pet_member_preference (
    member_id BIGINT UNSIGNED NOT NULL,
    order_notifications TINYINT NOT NULL DEFAULT 1,
    system_notifications TINYINT NOT NULL DEFAULT 1,
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id),
    CONSTRAINT fk_preference_member FOREIGN KEY (member_id) REFERENCES pet_member(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='会员站内通知偏好';
CREATE TABLE IF NOT EXISTS pet_member_favorite (
    member_id BIGINT UNSIGNED NOT NULL,
    item_id BIGINT UNSIGNED NOT NULL,
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id, item_id),
    KEY idx_favorite_time (member_id, create_time, item_id),
    CONSTRAINT fk_favorite_member FOREIGN KEY (member_id) REFERENCES pet_member(id),
    CONSTRAINT fk_favorite_item FOREIGN KEY (item_id) REFERENCES pet_item(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='会员商品收藏';
CREATE TABLE IF NOT EXISTS pet_payment_request (
    idempotency_key VARCHAR(64) NOT NULL,
    payment_id BIGINT UNSIGNED NOT NULL,
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idempotency_key),
    KEY idx_payment_request_payment (payment_id),
    CONSTRAINT fk_payment_request FOREIGN KEY (payment_id) REFERENCES pet_payment(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='支付请求幂等映射';
