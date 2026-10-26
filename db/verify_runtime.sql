-- Read-only invariants for an already-used database. Does not require seed counts.
SET NAMES utf8mb4;
SELECT 'R01 feature tables' AS check_item,
 IF(COUNT(*)=3,'PASS','FAIL') AS result FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name IN ('pet_member_favorite','pet_member_preference','pet_payment_request')
UNION ALL SELECT 'R02 preference ownership', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_member_preference p LEFT JOIN pet_member m ON m.id=p.member_id WHERE m.id IS NULL
UNION ALL SELECT 'R03 favorite ownership', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_member_favorite f LEFT JOIN pet_member m ON m.id=f.member_id LEFT JOIN pet_item i ON i.id=f.item_id
 WHERE m.id IS NULL OR i.id IS NULL
UNION ALL SELECT 'R04 payment request references', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_payment_request r LEFT JOIN pet_payment p ON p.id=r.payment_id WHERE p.id IS NULL
UNION ALL SELECT 'R05 exactly one default per address book', IF(COUNT(*)=0,'PASS','FAIL')
 FROM (SELECT member_id FROM pet_address GROUP BY member_id HAVING SUM(is_default=1)<>1) bad
UNION ALL SELECT 'R06 nonnegative inventory', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_item_sku WHERE stock<0
UNION ALL SELECT 'R07 valid preferences', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_member_preference WHERE order_notifications NOT IN (0,1) OR system_notifications NOT IN (0,1)
UNION ALL SELECT 'R08 successful payment order and amount', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_payment p LEFT JOIN pet_order o ON o.order_no=p.order_no
 WHERE p.status='SUCCESS' AND (o.id IS NULL OR o.status NOT IN (2,3,4,7,8) OR p.amount<>o.pay_amount)
UNION ALL SELECT 'R09 two-level category tree', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_category c LEFT JOIN pet_category parent ON parent.id=c.parent_id
 WHERE c.parent_id<>0 AND (parent.id IS NULL OR parent.parent_id<>0)
UNION ALL SELECT 'R10 product category references', IF(COUNT(*)=0,'PASS','FAIL')
 FROM pet_item i LEFT JOIN pet_category c ON c.id=i.category_id
 WHERE i.del_flag='0' AND c.id IS NULL;
