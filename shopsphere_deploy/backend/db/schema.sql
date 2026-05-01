-- ================================================================
-- ShopSphere — E-Commerce Database
-- CS F212 Database Systems | BITS Pilani Dubai
-- Group of 6 → 15 Tables | 5 Views | 5 Functions
--              12 Triggers | 7 Stored Procedures
-- ================================================================

DROP DATABASE IF EXISTS shopsphere;
CREATE DATABASE shopsphere
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shopsphere;

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- ================================================================
-- TABLE 1: CATEGORIES  (self-referencing for sub-categories)
-- ================================================================
CREATE TABLE CATEGORIES (
  category_id  INT           NOT NULL AUTO_INCREMENT,
  name         VARCHAR(100)  NOT NULL,
  parent_id    INT           DEFAULT NULL,
  description  TEXT,
  icon_url     VARCHAR(300),
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY  (category_id),
  UNIQUE KEY   uq_cat_name (name),
  CONSTRAINT   fk_cat_parent FOREIGN KEY (parent_id)
               REFERENCES CATEGORIES(category_id) ON DELETE SET NULL,
  INDEX idx_cat_parent (parent_id),
  INDEX idx_cat_active (is_active)
) ENGINE=InnoDB COMMENT='Product category hierarchy (self-referencing)';

-- ================================================================
-- TABLE 2: USERS
-- ================================================================
CREATE TABLE USERS (
  user_id       INT           NOT NULL AUTO_INCREMENT,
  email         VARCHAR(191)  NOT NULL,
  password_hash VARCHAR(255)  NOT NULL,
  full_name     VARCHAR(150)  NOT NULL,
  phone         VARCHAR(25),
  role          ENUM('customer','admin','vendor') NOT NULL DEFAULT 'customer',
  is_active     TINYINT(1)    NOT NULL DEFAULT 1,
  last_login    TIMESTAMP     NULL DEFAULT NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY   (user_id),
  UNIQUE KEY    uq_user_email (email),
  INDEX         idx_user_role (role),
  INDEX         idx_user_active (is_active)
) ENGINE=InnoDB COMMENT='Registered users — customers, admins, vendors';

-- ================================================================
-- TABLE 3: ADDRESSES  (separated from USERS — satisfies 2NF/BCNF)
-- ================================================================
CREATE TABLE ADDRESSES (
  address_id   INT           NOT NULL AUTO_INCREMENT,
  user_id      INT           NOT NULL,
  label        VARCHAR(50)   DEFAULT 'Home',
  full_name    VARCHAR(150)  NOT NULL,
  street       VARCHAR(255)  NOT NULL,
  city         VARCHAR(100)  NOT NULL,
  state        VARCHAR(100),
  country      VARCHAR(100)  NOT NULL DEFAULT 'UAE',
  postal_code  VARCHAR(20),
  is_default   TINYINT(1)    NOT NULL DEFAULT 0,
  PRIMARY KEY  (address_id),
  CONSTRAINT   fk_addr_user FOREIGN KEY (user_id)
               REFERENCES USERS(user_id) ON DELETE CASCADE,
  INDEX        idx_addr_user (user_id)
) ENGINE=InnoDB COMMENT='User delivery addresses (one user, many addresses)';

-- ================================================================
-- TABLE 4: BRANDS
-- ================================================================
CREATE TABLE BRANDS (
  brand_id     INT           NOT NULL AUTO_INCREMENT,
  name         VARCHAR(100)  NOT NULL,
  country      VARCHAR(100),
  website      VARCHAR(300),
  logo_url     VARCHAR(300),
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY  (brand_id),
  UNIQUE KEY   uq_brand_name (name)
) ENGINE=InnoDB COMMENT='Product brands — extracted to remove transitive dependency';

-- ================================================================
-- TABLE 5: PRODUCTS
-- ================================================================
CREATE TABLE PRODUCTS (
  product_id   INT            NOT NULL AUTO_INCREMENT,
  category_id  INT            NOT NULL,
  brand_id     INT            DEFAULT NULL,
  name         VARCHAR(255)   NOT NULL,
  slug         VARCHAR(300)   NOT NULL,
  description  TEXT,
  price        DECIMAL(10,2)  NOT NULL,
  compare_price DECIMAL(10,2) DEFAULT NULL COMMENT 'Original price before discount',
  stock_qty    INT            NOT NULL DEFAULT 0,
  sku          VARCHAR(100)   UNIQUE,
  weight_kg    DECIMAL(6,3)   DEFAULT NULL,
  avg_rating   DECIMAL(3,2)   NOT NULL DEFAULT 0.00,
  review_count INT            NOT NULL DEFAULT 0,
  is_active    TINYINT(1)     NOT NULL DEFAULT 1,
  is_featured  TINYINT(1)     NOT NULL DEFAULT 0,
  created_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY  (product_id),
  UNIQUE KEY   uq_product_slug (slug),
  CONSTRAINT   fk_prod_cat   FOREIGN KEY (category_id) REFERENCES CATEGORIES(category_id),
  CONSTRAINT   fk_prod_brand FOREIGN KEY (brand_id)    REFERENCES BRANDS(brand_id) ON DELETE SET NULL,
  CONSTRAINT   chk_price     CHECK (price >= 0),
  CONSTRAINT   chk_stock     CHECK (stock_qty >= 0),
  CONSTRAINT   chk_rating    CHECK (avg_rating BETWEEN 0 AND 5),
  INDEX idx_prod_cat     (category_id),
  INDEX idx_prod_brand   (brand_id),
  INDEX idx_prod_price   (price),
  INDEX idx_prod_rating  (avg_rating),
  INDEX idx_prod_active  (is_active),
  INDEX idx_prod_featured(is_featured),
  FULLTEXT INDEX ft_prod_search (name, description)
) ENGINE=InnoDB COMMENT='Products — BCNF: brand extracted, category extracted';

-- ================================================================
-- TABLE 6: PRODUCT_IMAGES  (multi-valued attr → own table, 1NF)
-- ================================================================
CREATE TABLE PRODUCT_IMAGES (
  image_id     INT          NOT NULL AUTO_INCREMENT,
  product_id   INT          NOT NULL,
  url          VARCHAR(500) NOT NULL,
  alt_text     VARCHAR(200),
  is_primary   TINYINT(1)   NOT NULL DEFAULT 0,
  sort_order   INT          NOT NULL DEFAULT 0,
  PRIMARY KEY  (image_id),
  CONSTRAINT   fk_img_prod FOREIGN KEY (product_id)
               REFERENCES PRODUCTS(product_id) ON DELETE CASCADE,
  INDEX        idx_img_prod (product_id)
) ENGINE=InnoDB COMMENT='Product images — multi-valued attribute extracted for 1NF';

-- ================================================================
-- TABLE 7: PRODUCT_ATTRIBUTES  (EAV for flexible specs)
-- ================================================================
CREATE TABLE PRODUCT_ATTRIBUTES (
  attr_id      INT          NOT NULL AUTO_INCREMENT,
  product_id   INT          NOT NULL,
  attr_name    VARCHAR(100) NOT NULL,
  attr_value   VARCHAR(255) NOT NULL,
  PRIMARY KEY  (attr_id),
  CONSTRAINT   fk_attr_prod FOREIGN KEY (product_id)
               REFERENCES PRODUCTS(product_id) ON DELETE CASCADE,
  UNIQUE KEY   uq_prod_attr (product_id, attr_name),
  INDEX        idx_attr_prod (product_id)
) ENGINE=InnoDB COMMENT='Flexible product specs (RAM, Color, Size, etc.)';

-- ================================================================
-- TABLE 8: COUPONS
-- ================================================================
CREATE TABLE COUPONS (
  coupon_id     INT           NOT NULL AUTO_INCREMENT,
  code          VARCHAR(50)   NOT NULL,
  description   VARCHAR(255),
  type          ENUM('percentage','fixed') NOT NULL DEFAULT 'percentage',
  discount_value DECIMAL(10,2) NOT NULL,
  min_order_amt DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  max_discount  DECIMAL(10,2) DEFAULT NULL COMMENT 'Cap for percentage coupons',
  expires_at    DATE          NOT NULL,
  max_uses      INT           NOT NULL DEFAULT 100,
  used_count    INT           NOT NULL DEFAULT 0,
  is_active     TINYINT(1)    NOT NULL DEFAULT 1,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY   (coupon_id),
  UNIQUE KEY    uq_coupon_code (code),
  CONSTRAINT    chk_discount_val CHECK (discount_value > 0),
  INDEX         idx_coupon_active (is_active),
  INDEX         idx_coupon_expires (expires_at)
) ENGINE=InnoDB COMMENT='Discount coupons — supports % and fixed amount';

-- ================================================================
-- TABLE 9: ORDERS
-- ================================================================
CREATE TABLE ORDERS (
  order_id      INT            NOT NULL AUTO_INCREMENT,
  user_id       INT            NOT NULL,
  address_id    INT            NOT NULL,
  coupon_id     INT            DEFAULT NULL,
  subtotal      DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  discount_amt  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  shipping_fee  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  tax_amt       DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  total_amount  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  status        ENUM('pending','confirmed','processing','shipped','delivered','cancelled','refunded')
                               NOT NULL DEFAULT 'pending',
  shipping_method VARCHAR(100) DEFAULT 'Standard',
  tracking_no   VARCHAR(100)   DEFAULT NULL,
  notes         TEXT,
  ordered_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY   (order_id),
  CONSTRAINT    fk_ord_user   FOREIGN KEY (user_id)    REFERENCES USERS(user_id),
  CONSTRAINT    fk_ord_addr   FOREIGN KEY (address_id) REFERENCES ADDRESSES(address_id),
  CONSTRAINT    fk_ord_coupon FOREIGN KEY (coupon_id)  REFERENCES COUPONS(coupon_id) ON DELETE SET NULL,
  INDEX         idx_ord_user   (user_id),
  INDEX         idx_ord_status (status),
  INDEX         idx_ord_date   (ordered_at)
) ENGINE=InnoDB COMMENT='Customer orders — master table';

-- ================================================================
-- TABLE 10: ORDER_ITEMS
-- ================================================================
CREATE TABLE ORDER_ITEMS (
  item_id      INT            NOT NULL AUTO_INCREMENT,
  order_id     INT            NOT NULL,
  product_id   INT            NOT NULL,
  quantity     INT            NOT NULL,
  unit_price   DECIMAL(10,2)  NOT NULL COMMENT 'Price at time of order (snapshot)',
  PRIMARY KEY  (item_id),
  CONSTRAINT   fk_oi_order   FOREIGN KEY (order_id)   REFERENCES ORDERS(order_id)   ON DELETE CASCADE,
  CONSTRAINT   fk_oi_product FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id),
  CONSTRAINT   chk_oi_qty    CHECK (quantity > 0),
  UNIQUE KEY   uq_order_product (order_id, product_id),
  INDEX        idx_oi_product (product_id)
) ENGINE=InnoDB COMMENT='Line items per order — price snapshot prevents transitive dep';

-- ================================================================
-- TABLE 11: PAYMENTS
-- ================================================================
CREATE TABLE PAYMENTS (
  payment_id   INT            NOT NULL AUTO_INCREMENT,
  order_id     INT            NOT NULL,
  method       ENUM('credit_card','debit_card','paypal','bank_transfer','cash_on_delivery','apple_pay','google_pay')
               NOT NULL,
  status       ENUM('pending','completed','failed','refunded','partially_refunded')
               NOT NULL DEFAULT 'pending',
  amount       DECIMAL(10,2)  NOT NULL,
  txn_ref      VARCHAR(150)   DEFAULT NULL,
  gateway_resp TEXT           DEFAULT NULL,
  paid_at      TIMESTAMP      NULL DEFAULT NULL,
  PRIMARY KEY  (payment_id),
  CONSTRAINT   fk_pay_order FOREIGN KEY (order_id)
               REFERENCES ORDERS(order_id) ON DELETE CASCADE,
  UNIQUE KEY   uq_pay_order (order_id),
  INDEX        idx_pay_status (status),
  INDEX        idx_pay_method (method)
) ENGINE=InnoDB COMMENT='Payment records — one per order (1:1 with ORDERS)';

-- ================================================================
-- TABLE 12: REVIEWS
-- ================================================================
CREATE TABLE REVIEWS (
  review_id    INT          NOT NULL AUTO_INCREMENT,
  user_id      INT          NOT NULL,
  product_id   INT          NOT NULL,
  order_id     INT          NOT NULL COMMENT 'Ensures only buyers review',
  rating       TINYINT      NOT NULL,
  title        VARCHAR(200),
  comment      TEXT,
  is_verified  TINYINT(1)   NOT NULL DEFAULT 1,
  helpful_count INT         NOT NULL DEFAULT 0,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY  (review_id),
  CONSTRAINT   fk_rev_user    FOREIGN KEY (user_id)    REFERENCES USERS(user_id)    ON DELETE CASCADE,
  CONSTRAINT   fk_rev_product FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id) ON DELETE CASCADE,
  CONSTRAINT   fk_rev_order   FOREIGN KEY (order_id)   REFERENCES ORDERS(order_id),
  CONSTRAINT   chk_rev_rating CHECK (rating BETWEEN 1 AND 5),
  UNIQUE KEY   uq_user_product_review (user_id, product_id),
  INDEX        idx_rev_product (product_id),
  INDEX        idx_rev_rating  (rating)
) ENGINE=InnoDB COMMENT='Verified product reviews — linked to orders for authenticity';

-- ================================================================
-- TABLE 13: CART_ITEMS
-- ================================================================
CREATE TABLE CART_ITEMS (
  cart_id      INT          NOT NULL AUTO_INCREMENT,
  user_id      INT          NOT NULL,
  product_id   INT          NOT NULL,
  quantity     INT          NOT NULL DEFAULT 1,
  added_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY  (cart_id),
  CONSTRAINT   fk_cart_user    FOREIGN KEY (user_id)    REFERENCES USERS(user_id)    ON DELETE CASCADE,
  CONSTRAINT   fk_cart_product FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id) ON DELETE CASCADE,
  CONSTRAINT   chk_cart_qty    CHECK (quantity > 0),
  UNIQUE KEY   uq_cart_user_product (user_id, product_id),
  INDEX        idx_cart_user (user_id)
) ENGINE=InnoDB COMMENT='Shopping cart — temporary before checkout';

-- ================================================================
-- TABLE 14: WISHLISTS
-- ================================================================
CREATE TABLE WISHLISTS (
  wishlist_id  INT          NOT NULL AUTO_INCREMENT,
  user_id      INT          NOT NULL,
  product_id   INT          NOT NULL,
  added_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY  (wishlist_id),
  CONSTRAINT   fk_wish_user    FOREIGN KEY (user_id)    REFERENCES USERS(user_id)    ON DELETE CASCADE,
  CONSTRAINT   fk_wish_product FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id) ON DELETE CASCADE,
  UNIQUE KEY   uq_wish_user_product (user_id, product_id),
  INDEX        idx_wish_user (user_id)
) ENGINE=InnoDB COMMENT='User wishlists / saved items';

-- ================================================================
-- TABLE 15: AUDIT_LOG
-- ================================================================
CREATE TABLE AUDIT_LOG (
  log_id       INT          NOT NULL AUTO_INCREMENT,
  table_name   VARCHAR(60)  NOT NULL,
  record_id    INT          NOT NULL,
  action       ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  changed_by   INT          DEFAULT NULL,
  old_value    JSON         DEFAULT NULL,
  new_value    JSON         DEFAULT NULL,
  ip_address   VARCHAR(45)  DEFAULT NULL,
  changed_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY  (log_id),
  INDEX        idx_audit_table  (table_name),
  INDEX        idx_audit_record (record_id),
  INDEX        idx_audit_date   (changed_at)
) ENGINE=InnoDB COMMENT='Immutable audit trail for key table changes';

SET FOREIGN_KEY_CHECKS = 1;

-- ================================================================
-- VIEWS
-- ================================================================

-- View 1: Complete product catalog with brand, category, image
CREATE OR REPLACE VIEW vw_product_catalog AS
SELECT
  p.product_id,
  p.name           AS product_name,
  p.slug,
  p.description,
  p.price,
  p.compare_price,
  ROUND(((p.compare_price - p.price) / p.compare_price) * 100) AS discount_pct,
  p.stock_qty,
  p.avg_rating,
  p.review_count,
  p.is_featured,
  p.is_active,
  c.category_id,
  c.name           AS category_name,
  pc.name          AS parent_category,
  b.name           AS brand_name,
  b.country        AS brand_country,
  pi.url           AS primary_image,
  p.created_at
FROM PRODUCTS p
JOIN  CATEGORIES c   ON p.category_id  = c.category_id
LEFT JOIN CATEGORIES pc ON c.parent_id = pc.category_id
LEFT JOIN BRANDS b   ON p.brand_id     = b.brand_id
LEFT JOIN PRODUCT_IMAGES pi
  ON pi.product_id = p.product_id AND pi.is_primary = 1;

-- View 2: Order summary with customer, address, payment
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
  o.order_id,
  o.status,
  o.subtotal,
  o.discount_amt,
  o.shipping_fee,
  o.tax_amt,
  o.total_amount,
  o.ordered_at,
  o.tracking_no,
  u.user_id,
  u.full_name      AS customer_name,
  u.email,
  u.phone,
  CONCAT(a.street, ', ', a.city, ', ', a.country) AS delivery_address,
  COUNT(oi.item_id)AS item_count,
  py.method        AS payment_method,
  py.status        AS payment_status
FROM ORDERS o
JOIN USERS       u  ON o.user_id    = u.user_id
JOIN ADDRESSES   a  ON o.address_id = a.address_id
JOIN ORDER_ITEMS oi ON o.order_id   = oi.order_id
LEFT JOIN PAYMENTS py ON o.order_id = py.order_id
GROUP BY o.order_id, o.status, o.subtotal, o.discount_amt,
         o.shipping_fee, o.tax_amt, o.total_amount, o.ordered_at,
         o.tracking_no, u.user_id, u.full_name, u.email, u.phone,
         a.street, a.city, a.country, py.method, py.status;

-- View 3: Revenue breakdown by category
CREATE OR REPLACE VIEW vw_revenue_by_category AS
SELECT
  c.category_id,
  c.name                               AS category_name,
  pc.name                              AS parent_category,
  COUNT(DISTINCT o.order_id)           AS total_orders,
  SUM(oi.quantity)                     AS units_sold,
  ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM ORDER_ITEMS oi
JOIN PRODUCTS   p  ON oi.product_id = p.product_id
JOIN CATEGORIES c  ON p.category_id = c.category_id
LEFT JOIN CATEGORIES pc ON c.parent_id = pc.category_id
JOIN ORDERS     o  ON oi.order_id   = o.order_id
WHERE o.status NOT IN ('cancelled','refunded')
GROUP BY c.category_id, c.name, pc.name;

-- View 4: Low-stock alert (<= 10 units)
CREATE OR REPLACE VIEW vw_low_stock AS
SELECT
  p.product_id,
  p.name,
  p.sku,
  c.name   AS category_name,
  b.name   AS brand_name,
  p.stock_qty,
  p.price
FROM PRODUCTS p
JOIN CATEGORIES c ON p.category_id = c.category_id
LEFT JOIN BRANDS b ON p.brand_id    = b.brand_id
WHERE p.stock_qty <= 10 AND p.is_active = 1
ORDER BY p.stock_qty ASC;

-- View 5: Customer lifetime value (CLV)
CREATE OR REPLACE VIEW vw_customer_ltv AS
SELECT
  u.user_id,
  u.full_name,
  u.email,
  u.phone,
  u.created_at                               AS member_since,
  COUNT(DISTINCT o.order_id)                 AS total_orders,
  COALESCE(SUM(o.total_amount), 0)           AS lifetime_value,
  COALESCE(AVG(o.total_amount), 0)           AS avg_order_value,
  MAX(o.ordered_at)                          AS last_order_date,
  COALESCE(COUNT(DISTINCT r.review_id), 0)   AS reviews_written
FROM USERS u
LEFT JOIN ORDERS  o ON u.user_id = o.user_id  AND o.status NOT IN ('cancelled','refunded')
LEFT JOIN REVIEWS r ON u.user_id = r.user_id
WHERE u.role = 'customer'
GROUP BY u.user_id, u.full_name, u.email, u.phone, u.created_at;

-- ================================================================
-- STORED FUNCTIONS
-- ================================================================

DELIMITER $$

-- Function 1: Calculate discounted price given % or fixed coupon
CREATE FUNCTION fn_apply_coupon(
  p_subtotal     DECIMAL(10,2),
  p_type         VARCHAR(20),
  p_discount_val DECIMAL(10,2),
  p_max_discount DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE v_disc DECIMAL(10,2);
  IF p_type = 'percentage' THEN
    SET v_disc = ROUND(p_subtotal * p_discount_val / 100, 2);
    IF p_max_discount IS NOT NULL AND v_disc > p_max_discount THEN
      SET v_disc = p_max_discount;
    END IF;
  ELSE
    SET v_disc = p_discount_val;
  END IF;
  IF v_disc > p_subtotal THEN SET v_disc = p_subtotal; END IF;
  RETURN v_disc;
END$$

-- Function 2: Get cart subtotal for a user
CREATE FUNCTION fn_cart_subtotal(p_user_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(10,2);
  SELECT COALESCE(SUM(ci.quantity * p.price), 0)
  INTO   v_total
  FROM   CART_ITEMS ci
  JOIN   PRODUCTS   p ON ci.product_id = p.product_id
  WHERE  ci.user_id = p_user_id;
  RETURN v_total;
END$$

-- Function 3: Validate coupon — returns discount amount or 0
CREATE FUNCTION fn_validate_coupon(p_code VARCHAR(50), p_subtotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_type   VARCHAR(20);
  DECLARE v_val    DECIMAL(10,2);
  DECLARE v_max    DECIMAL(10,2);
  DECLARE v_minord DECIMAL(10,2);
  DECLARE v_found  INT DEFAULT 0;

  SELECT COUNT(*), type, discount_value, max_discount, min_order_amt
  INTO   v_found, v_type, v_val, v_max, v_minord
  FROM   COUPONS
  WHERE  code = p_code AND is_active = 1
    AND  expires_at >= CURDATE() AND used_count < max_uses
  GROUP BY type, discount_value, max_discount, min_order_amt;

  IF v_found = 0 OR p_subtotal < v_minord THEN RETURN 0; END IF;
  RETURN fn_apply_coupon(p_subtotal, v_type, v_val, v_max);
END$$

-- Function 4: Get total orders count for a customer
CREATE FUNCTION fn_customer_order_count(p_user_id INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_cnt INT;
  SELECT COUNT(*) INTO v_cnt FROM ORDERS
  WHERE user_id = p_user_id AND status NOT IN ('cancelled','refunded');
  RETURN v_cnt;
END$$

-- Function 5: Calculate shipping fee based on order weight
CREATE FUNCTION fn_shipping_fee(p_total_weight DECIMAL(8,3))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE v_fee DECIMAL(10,2);
  IF    p_total_weight <= 0      THEN SET v_fee = 0.00;
  ELSEIF p_total_weight <= 1.0   THEN SET v_fee = 10.00;
  ELSEIF p_total_weight <= 5.0   THEN SET v_fee = 20.00;
  ELSEIF p_total_weight <= 10.0  THEN SET v_fee = 35.00;
  ELSE                                SET v_fee = 50.00;
  END IF;
  RETURN v_fee;
END$$

DELIMITER ;

-- ================================================================
-- TRIGGERS
-- ================================================================

DELIMITER $$

-- Trigger 1: BEFORE INSERT ORDER_ITEMS — prevent over-ordering
CREATE TRIGGER trg_check_stock_before_order
BEFORE INSERT ON ORDER_ITEMS
FOR EACH ROW
BEGIN
  DECLARE v_stock INT;
  DECLARE v_name  VARCHAR(255);
  SELECT stock_qty, name INTO v_stock, v_name
  FROM PRODUCTS WHERE product_id = NEW.product_id;
  IF v_stock < NEW.quantity THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Insufficient stock for this product';
  END IF;
END$$

-- Trigger 2: AFTER INSERT ORDER_ITEMS — deduct stock
CREATE TRIGGER trg_deduct_stock_after_order
AFTER INSERT ON ORDER_ITEMS
FOR EACH ROW
BEGIN
  UPDATE PRODUCTS
  SET stock_qty = stock_qty - NEW.quantity
  WHERE product_id = NEW.product_id;
END$$

-- Trigger 3: AFTER UPDATE ORDERS (status → cancelled) — restore stock
CREATE TRIGGER trg_restore_stock_on_cancel
AFTER UPDATE ON ORDERS
FOR EACH ROW
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status NOT IN ('cancelled','refunded') THEN
    UPDATE PRODUCTS p
    JOIN   ORDER_ITEMS oi ON p.product_id = oi.product_id
    SET    p.stock_qty = p.stock_qty + oi.quantity
    WHERE  oi.order_id = NEW.order_id;
    -- Audit the cancellation
    INSERT INTO AUDIT_LOG (table_name, record_id, action, old_value, new_value)
    VALUES ('ORDERS', NEW.order_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status),
      JSON_OBJECT('status', NEW.status, 'note', 'stock restored'));
  END IF;
END$$

-- Trigger 4: AFTER INSERT REVIEWS — update avg_rating + review_count
CREATE TRIGGER trg_update_rating_on_insert
AFTER INSERT ON REVIEWS
FOR EACH ROW
BEGIN
  UPDATE PRODUCTS
  SET avg_rating   = (SELECT AVG(rating)   FROM REVIEWS WHERE product_id = NEW.product_id),
      review_count = (SELECT COUNT(*)       FROM REVIEWS WHERE product_id = NEW.product_id)
  WHERE product_id = NEW.product_id;
END$$

-- Trigger 5: AFTER UPDATE REVIEWS — recalculate avg_rating
CREATE TRIGGER trg_update_rating_on_update
AFTER UPDATE ON REVIEWS
FOR EACH ROW
BEGIN
  UPDATE PRODUCTS
  SET avg_rating   = (SELECT AVG(rating) FROM REVIEWS WHERE product_id = NEW.product_id),
      review_count = (SELECT COUNT(*)    FROM REVIEWS WHERE product_id = NEW.product_id)
  WHERE product_id = NEW.product_id;
END$$

-- Trigger 6: AFTER DELETE REVIEWS — recalculate avg_rating
CREATE TRIGGER trg_update_rating_on_delete
AFTER DELETE ON REVIEWS
FOR EACH ROW
BEGIN
  UPDATE PRODUCTS
  SET avg_rating   = COALESCE((SELECT AVG(rating) FROM REVIEWS WHERE product_id = OLD.product_id), 0),
      review_count = (SELECT COUNT(*) FROM REVIEWS WHERE product_id = OLD.product_id)
  WHERE product_id = OLD.product_id;
END$$

-- Trigger 7: AFTER INSERT ORDERS — increment coupon used_count
CREATE TRIGGER trg_increment_coupon_usage
AFTER INSERT ON ORDERS
FOR EACH ROW
BEGIN
  IF NEW.coupon_id IS NOT NULL THEN
    UPDATE COUPONS SET used_count = used_count + 1 WHERE coupon_id = NEW.coupon_id;
  END IF;
END$$

-- Trigger 8: BEFORE INSERT PRODUCTS — auto-generate slug from name
CREATE TRIGGER trg_auto_slug_on_insert
BEFORE INSERT ON PRODUCTS
FOR EACH ROW
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    SET NEW.slug = LOWER(REPLACE(REPLACE(REPLACE(NEW.name, ' ', '-'), '/', '-'), '"', ''));
  END IF;
END$$

-- Trigger 9: AFTER INSERT PRODUCTS — audit new product
CREATE TRIGGER trg_audit_product_insert
AFTER INSERT ON PRODUCTS
FOR EACH ROW
BEGIN
  INSERT INTO AUDIT_LOG (table_name, record_id, action, new_value)
  VALUES ('PRODUCTS', NEW.product_id, 'INSERT',
    JSON_OBJECT('name', NEW.name, 'price', NEW.price, 'stock', NEW.stock_qty));
END$$

-- Trigger 10: AFTER UPDATE PRODUCTS — audit price/stock changes
CREATE TRIGGER trg_audit_product_update
AFTER UPDATE ON PRODUCTS
FOR EACH ROW
BEGIN
  IF OLD.price != NEW.price OR OLD.stock_qty != NEW.stock_qty THEN
    INSERT INTO AUDIT_LOG (table_name, record_id, action, old_value, new_value)
    VALUES ('PRODUCTS', NEW.product_id, 'UPDATE',
      JSON_OBJECT('price', OLD.price, 'stock', OLD.stock_qty),
      JSON_OBJECT('price', NEW.price, 'stock', NEW.stock_qty));
  END IF;
END$$

-- Trigger 11: BEFORE INSERT ADDRESSES — ensure only one default per user
CREATE TRIGGER trg_single_default_address
BEFORE INSERT ON ADDRESSES
FOR EACH ROW
BEGIN
  IF NEW.is_default = 1 THEN
    UPDATE ADDRESSES SET is_default = 0 WHERE user_id = NEW.user_id;
  END IF;
END$$

-- Trigger 12: AFTER INSERT USERS — audit new registrations
CREATE TRIGGER trg_audit_user_register
AFTER INSERT ON USERS
FOR EACH ROW
BEGIN
  INSERT INTO AUDIT_LOG (table_name, record_id, action, new_value)
  VALUES ('USERS', NEW.user_id, 'INSERT',
    JSON_OBJECT('email', NEW.email, 'role', NEW.role));
END$$

DELIMITER ;

-- ================================================================
-- STORED PROCEDURES
-- ================================================================

DELIMITER $$

-- Procedure 1: Full checkout — validates cart, coupon, calculates shipping & tax
CREATE PROCEDURE sp_place_order(
  IN  p_user_id       INT,
  IN  p_address_id    INT,
  IN  p_coupon_code   VARCHAR(50),
  IN  p_pay_method    VARCHAR(50),
  IN  p_ship_method   VARCHAR(100),
  OUT p_order_id      INT,
  OUT p_message       VARCHAR(255)
)
BEGIN
  DECLARE v_coupon_id    INT          DEFAULT NULL;
  DECLARE v_coupon_type  VARCHAR(20)  DEFAULT 'percentage';
  DECLARE v_coupon_val   DECIMAL(10,2) DEFAULT 0;
  DECLARE v_coupon_max   DECIMAL(10,2) DEFAULT NULL;
  DECLARE v_coupon_min   DECIMAL(10,2) DEFAULT 0;
  DECLARE v_subtotal     DECIMAL(10,2);
  DECLARE v_discount     DECIMAL(10,2) DEFAULT 0;
  DECLARE v_weight       DECIMAL(8,3)  DEFAULT 0;
  DECLARE v_shipping     DECIMAL(10,2) DEFAULT 0;
  DECLARE v_tax          DECIMAL(10,2);
  DECLARE v_total        DECIMAL(10,2);
  DECLARE v_cart_count   INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    GET DIAGNOSTICS CONDITION 1 p_message = MESSAGE_TEXT;
    SET p_order_id = -1;
  END;

  -- 1. Validate cart not empty
  SELECT COUNT(*) INTO v_cart_count FROM CART_ITEMS WHERE user_id = p_user_id;
  IF v_cart_count = 0 THEN
    SET p_order_id = -1; SET p_message = 'Cart is empty'; LEAVE sp_place_order;
  END IF;

  -- 2. Validate address belongs to user
  IF NOT EXISTS (
    SELECT 1 FROM ADDRESSES WHERE address_id = p_address_id AND user_id = p_user_id
  ) THEN
    SET p_order_id = -1; SET p_message = 'Invalid delivery address'; LEAVE sp_place_order;
  END IF;

  -- 3. Resolve coupon
  IF p_coupon_code IS NOT NULL AND TRIM(p_coupon_code) != '' THEN
    SELECT coupon_id, type, discount_value, max_discount, min_order_amt
    INTO   v_coupon_id, v_coupon_type, v_coupon_val, v_coupon_max, v_coupon_min
    FROM   COUPONS
    WHERE  code = p_coupon_code AND is_active = 1
      AND  expires_at >= CURDATE() AND used_count < max_uses
    LIMIT  1;
    IF v_coupon_id IS NULL THEN
      SET p_order_id = -1; SET p_message = 'Invalid or expired coupon'; LEAVE sp_place_order;
    END IF;
  END IF;

  -- 4. Calculate subtotal
  SET v_subtotal = fn_cart_subtotal(p_user_id);

  -- 5. Validate min order for coupon
  IF v_coupon_id IS NOT NULL AND v_subtotal < v_coupon_min THEN
    SET p_order_id = -1;
    SET p_message  = CONCAT('Minimum order of AED ', v_coupon_min, ' required for this coupon');
    LEAVE sp_place_order;
  END IF;

  -- 6. Calculate discount using function
  IF v_coupon_id IS NOT NULL THEN
    SET v_discount = fn_apply_coupon(v_subtotal, v_coupon_type, v_coupon_val, v_coupon_max);
  END IF;

  -- 7. Calculate weight-based shipping
  SELECT COALESCE(SUM(ci.quantity * COALESCE(p.weight_kg, 0.5)), 0)
  INTO   v_weight
  FROM   CART_ITEMS ci JOIN PRODUCTS p ON ci.product_id = p.product_id
  WHERE  ci.user_id = p_user_id;
  SET v_shipping = fn_shipping_fee(v_weight);
  IF p_ship_method = 'Express' THEN SET v_shipping = v_shipping * 2; END IF;

  -- 8. Calculate VAT (5%)
  SET v_tax   = ROUND((v_subtotal - v_discount) * 0.05, 2);
  SET v_total = v_subtotal - v_discount + v_shipping + v_tax;

  START TRANSACTION;

  -- 9. Insert order
  INSERT INTO ORDERS
    (user_id, address_id, coupon_id, subtotal, discount_amt, shipping_fee, tax_amt, total_amount, status, shipping_method)
  VALUES
    (p_user_id, p_address_id, v_coupon_id, v_subtotal, v_discount, v_shipping, v_tax, v_total, 'confirmed', p_ship_method);
  SET p_order_id = LAST_INSERT_ID();

  -- 10. Copy cart to order items (trg_check_stock_before_order fires here)
  INSERT INTO ORDER_ITEMS (order_id, product_id, quantity, unit_price)
  SELECT p_order_id, ci.product_id, ci.quantity, p.price
  FROM   CART_ITEMS ci JOIN PRODUCTS p ON ci.product_id = p.product_id
  WHERE  ci.user_id = p_user_id;

  -- 11. Create payment record
  INSERT INTO PAYMENTS (order_id, method, status, amount)
  VALUES (p_order_id, p_pay_method, 'pending', v_total);

  -- 12. Clear cart
  DELETE FROM CART_ITEMS WHERE user_id = p_user_id;

  COMMIT;
  SET p_message = CONCAT('Order #', p_order_id, ' placed successfully. Total: AED ', v_total);
END$$

-- Procedure 2: Admin dashboard KPIs
CREATE PROCEDURE sp_dashboard_stats()
BEGIN
  SELECT
    (SELECT COUNT(*)  FROM USERS    WHERE role='customer' AND is_active=1) AS total_customers,
    (SELECT COUNT(*)  FROM ORDERS   WHERE status NOT IN ('cancelled','refunded')) AS total_orders,
    (SELECT COALESCE(SUM(total_amount),0) FROM ORDERS WHERE status='delivered')  AS total_revenue,
    (SELECT COUNT(*)  FROM PRODUCTS WHERE is_active=1)                           AS active_products,
    (SELECT COUNT(*)  FROM ORDERS   WHERE status='pending')                       AS pending_orders,
    (SELECT COUNT(*)  FROM PRODUCTS WHERE stock_qty<=10 AND is_active=1)          AS low_stock_count,
    (SELECT COUNT(*)  FROM REVIEWS)                                               AS total_reviews,
    (SELECT COALESCE(AVG(total_amount),0) FROM ORDERS WHERE status NOT IN ('cancelled','refunded')) AS avg_order_value,
    (SELECT COUNT(*)  FROM CART_ITEMS)                                            AS items_in_carts,
    (SELECT COALESCE(SUM(total_amount),0) FROM ORDERS WHERE status='delivered'
     AND ordered_at >= DATE_SUB(NOW(), INTERVAL 30 DAY))                          AS revenue_last_30d;
END$$

-- Procedure 3: Top N selling products with revenue
CREATE PROCEDURE sp_top_selling_products(IN p_limit INT)
BEGIN
  SELECT
    p.product_id,
    p.name,
    b.name                           AS brand,
    c.name                           AS category,
    SUM(oi.quantity)                 AS units_sold,
    ROUND(SUM(oi.quantity*oi.unit_price),2) AS revenue,
    p.avg_rating,
    p.review_count,
    p.stock_qty
  FROM ORDER_ITEMS oi
  JOIN PRODUCTS   p ON oi.product_id = p.product_id
  JOIN CATEGORIES c ON p.category_id = c.category_id
  LEFT JOIN BRANDS b ON p.brand_id   = b.brand_id
  JOIN ORDERS     o ON oi.order_id   = o.order_id
  WHERE o.status NOT IN ('cancelled','refunded')
  GROUP BY p.product_id, p.name, b.name, c.name, p.avg_rating, p.review_count, p.stock_qty
  ORDER BY units_sold DESC
  LIMIT p_limit;
END$$

-- Procedure 4: Full user order history (calls via stored proc for perf)
CREATE PROCEDURE sp_user_order_history(IN p_user_id INT)
BEGIN
  SELECT
    o.order_id,
    o.status,
    o.subtotal,
    o.discount_amt,
    o.shipping_fee,
    o.tax_amt,
    o.total_amount,
    o.ordered_at,
    o.tracking_no,
    o.shipping_method,
    p.product_id,
    p.name           AS product_name,
    b.name           AS brand_name,
    oi.quantity,
    oi.unit_price,
    (oi.quantity*oi.unit_price) AS line_total,
    py.method        AS payment_method,
    py.status        AS payment_status,
    pi.url           AS product_image
  FROM ORDERS      o
  JOIN ORDER_ITEMS oi ON o.order_id    = oi.order_id
  JOIN PRODUCTS    p  ON oi.product_id = p.product_id
  LEFT JOIN BRANDS b  ON p.brand_id    = b.brand_id
  LEFT JOIN PAYMENTS py ON o.order_id  = py.order_id
  LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
  WHERE o.user_id = p_user_id
  ORDER BY o.ordered_at DESC;
END$$

-- Procedure 5: Restock product (admin)
CREATE PROCEDURE sp_restock_product(
  IN p_product_id INT,
  IN p_quantity   INT,
  IN p_admin_id   INT
)
BEGIN
  DECLARE v_old INT;
  SELECT stock_qty INTO v_old FROM PRODUCTS WHERE product_id = p_product_id;

  UPDATE PRODUCTS SET stock_qty = stock_qty + p_quantity WHERE product_id = p_product_id;

  INSERT INTO AUDIT_LOG (table_name, record_id, action, changed_by, old_value, new_value)
  VALUES ('PRODUCTS', p_product_id, 'UPDATE', p_admin_id,
    JSON_OBJECT('stock', v_old),
    JSON_OBJECT('stock', v_old + p_quantity, 'restocked_by', p_admin_id));

  SELECT p_product_id AS product_id, v_old AS old_stock, v_old+p_quantity AS new_stock;
END$$

-- Procedure 6: Monthly revenue report
CREATE PROCEDURE sp_monthly_revenue(IN p_year INT)
BEGIN
  SELECT
    MONTH(ordered_at)                AS month_num,
    MONTHNAME(ordered_at)            AS month_name,
    COUNT(*)                         AS order_count,
    ROUND(SUM(total_amount), 2)      AS revenue,
    ROUND(AVG(total_amount), 2)      AS avg_order_value
  FROM ORDERS
  WHERE YEAR(ordered_at) = p_year
    AND status NOT IN ('cancelled','refunded')
  GROUP BY MONTH(ordered_at), MONTHNAME(ordered_at)
  ORDER BY month_num;
END$$

-- Procedure 7: Product search with full-text + filters
CREATE PROCEDURE sp_search_products(
  IN p_query       VARCHAR(255),
  IN p_category_id INT,
  IN p_brand_id    INT,
  IN p_min_price   DECIMAL(10,2),
  IN p_max_price   DECIMAL(10,2),
  IN p_sort        VARCHAR(30),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  SET @off = (p_page - 1) * p_limit;
  SET @sql = CONCAT(
    'SELECT p.product_id, p.name, p.price, p.avg_rating, p.stock_qty,
            c.name AS category_name, b.name AS brand_name, pi.url AS primary_image
     FROM PRODUCTS p
     JOIN CATEGORIES c ON p.category_id=c.category_id
     LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
     LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
     WHERE p.is_active=1 '
  );
  IF p_query IS NOT NULL AND p_query != '' THEN
    SET @sql = CONCAT(@sql, 'AND MATCH(p.name,p.description) AGAINST(', QUOTE(p_query), ' IN BOOLEAN MODE) ');
  END IF;
  IF p_category_id IS NOT NULL AND p_category_id > 0 THEN
    SET @sql = CONCAT(@sql, 'AND p.category_id=', p_category_id, ' ');
  END IF;
  IF p_brand_id IS NOT NULL AND p_brand_id > 0 THEN
    SET @sql = CONCAT(@sql, 'AND p.brand_id=', p_brand_id, ' ');
  END IF;
  IF p_min_price IS NOT NULL THEN SET @sql = CONCAT(@sql, 'AND p.price>=', p_min_price, ' '); END IF;
  IF p_max_price IS NOT NULL THEN SET @sql = CONCAT(@sql, 'AND p.price<=', p_max_price, ' '); END IF;
  SET @sql = CONCAT(@sql, 'ORDER BY ',
    CASE p_sort
      WHEN 'price_asc'  THEN 'p.price ASC '
      WHEN 'price_desc' THEN 'p.price DESC '
      WHEN 'rating'     THEN 'p.avg_rating DESC '
      WHEN 'newest'     THEN 'p.created_at DESC '
      WHEN 'featured'   THEN 'p.is_featured DESC, p.avg_rating DESC '
      ELSE 'p.is_featured DESC, p.created_at DESC '
    END,
    'LIMIT ', p_limit, ' OFFSET ', @off
  );
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- ================================================================
-- SEED DATA
-- ================================================================

-- Brands
INSERT INTO BRANDS (name, country, website) VALUES
  ('Apple',    'USA',     'https://apple.com'),
  ('Samsung',  'South Korea', 'https://samsung.com'),
  ('Sony',     'Japan',   'https://sony.com'),
  ('Nike',     'USA',     'https://nike.com'),
  ('Levi''s',  'USA',     'https://levi.com'),
  ('IKEA',     'Sweden',  'https://ikea.com'),
  ('Dell',     'USA',     'https://dell.com'),
  ('JBL',      'USA',     'https://jbl.com'),
  ('Lenovo',   'China',   'https://lenovo.com'),
  ('DJI',      'China',   'https://dji.com'),
  ('Instant Pot', 'Canada', 'https://instantpot.com'),
  ('Ninja',    'USA',     'https://ninjakitchen.com'),
  ('Zara',     'Spain',   'https://zara.com'),
  ('Yonex',    'Japan',   'https://yonex.com'),
  ('OnePlus',  'China',   'https://oneplus.com');

-- Categories
INSERT INTO CATEGORIES (name, parent_id, description) VALUES
  ('Electronics',        NULL, 'All electronic devices and gadgets'),
  ('Fashion',            NULL, 'Clothing, footwear and accessories'),
  ('Home & Kitchen',     NULL, 'Furniture, appliances and home essentials'),
  ('Books',              NULL, 'Physical and digital books'),
  ('Sports & Outdoors',  NULL, 'Sports equipment and activewear'),
  ('Smartphones',        1,    'Latest smartphones and mobile devices'),
  ('Laptops & PCs',      1,    'Laptops, desktops and accessories'),
  ('Audio',              1,    'Headphones, speakers and earbuds'),
  ('Cameras & Drones',   1,    'Cameras, drones and stabilisers'),
  ('Mens Fashion',       2,    'Mens clothing and footwear'),
  ('Womens Fashion',     2,    'Womens clothing and footwear'),
  ('Kitchen Appliances', 3,    'Cooking and kitchen devices'),
  ('Furniture',          3,    'Sofas, tables, chairs and shelves'),
  ('Racket Sports',      5,    'Badminton, tennis, squash gear'),
  ('Running',            5,    'Running shoes and apparel');

-- Users  (password123 → $2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi)
--        (adminpass123 → $2b$10$oVjkq0.57F7O3p6aBVcwBejopajEyxEMfF.6hfFsca.wj2oovNL4a)
INSERT INTO USERS (email, password_hash, full_name, phone, role) VALUES
  ('admin@shopsphere.com', '$2b$10$oVjkq0.57F7O3p6aBVcwBejopajEyxEMfF.6hfFsca.wj2oovNL4a', 'Admin User',    '+971501000000', 'admin'),
  ('alice@example.com',    '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Alice Johnson',  '+971502111111', 'customer'),
  ('bob@example.com',      '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Bob Smith',      '+971503222222', 'customer'),
  ('carol@example.com',    '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Carol Davis',    '+971504333333', 'customer'),
  ('dave@example.com',     '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Dave Wilson',    '+971505444444', 'customer'),
  ('eve@example.com',      '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Eve Martinez',   '+971506555555', 'customer'),
  ('frank@example.com',    '$2b$10$3.mfbKi6C2V6k/GjEdgL5uiqISPGe7VOguadz9fpll5XzFEX1znpi', 'Frank Chen',     '+971507666666', 'customer');

-- Addresses
INSERT INTO ADDRESSES (user_id, label, full_name, street, city, country, postal_code, is_default) VALUES
  (2, 'Home',   'Alice Johnson', '123 Sheikh Zayed Rd', 'Dubai',     'UAE', '00000', 1),
  (3, 'Home',   'Bob Smith',     '45 Corniche Rd',       'Abu Dhabi', 'UAE', '00000', 1),
  (4, 'Home',   'Carol Davis',   '78 Al Wahda St',       'Sharjah',   'UAE', '00000', 1),
  (5, 'Home',   'Dave Wilson',   '12 Clock Tower Sq',    'Al Ain',    'UAE', '00000', 1),
  (6, 'Home',   'Eve Martinez',  '99 Marina Walk',       'Dubai',     'UAE', '00000', 1),
  (7, 'Office', 'Frank Chen',    '5 Al Reem Island',     'Abu Dhabi', 'UAE', '00000', 1);

-- Products (20 products)
INSERT INTO PRODUCTS (category_id, brand_id, name, slug, description, price, compare_price, stock_qty, sku, weight_kg, is_featured) VALUES
  (6,  1,  'iPhone 15 Pro',             'iphone-15-pro',           'Titanium body A17 Pro chip 48MP ProCamera system ProMotion display',                         4999.00,  5499.00, 48, 'APL-IP15P-BLK',  0.187, 1),
  (6,  2,  'Samsung Galaxy S24 Ultra',  'samsung-galaxy-s24-ultra','Snapdragon 8 Gen 3 200MP camera integrated S-Pen titanium frame',                            4499.00,  4999.00, 38, 'SAM-S24U-BLK',   0.232, 1),
  (6,  15, 'OnePlus 12',                'oneplus-12',              'Snapdragon 8 Gen 3 Hasselblad cameras 100W SUPERVOOC charging',                               2999.00,  3299.00, 58, 'OP-12-GRN',      0.220, 0),
  (7,  1,  'MacBook Pro 14 M3 Pro',     'macbook-pro-14-m3-pro',   'Apple M3 Pro chip 18GB unified memory Liquid Retina XDR display',                            9999.00, 11499.00, 23, 'APL-MBP14-M3P',  1.550, 1),
  (7,  7,  'Dell XPS 15',               'dell-xps-15',             'Intel Core i9-13900H 4K OLED display 32GB RAM 1TB SSD',                                      7999.00,  8999.00, 18, 'DEL-XPS15-OLED', 1.860, 0),
  (7,  9,  'Lenovo ThinkPad X1 Carbon', 'lenovo-thinkpad-x1',      'Ultra-light 1.12kg business laptop 14 IPS display vPro security',                            6499.00,  7299.00, 33, 'LEN-X1C-GEN11',  1.120, 0),
  (8,  3,  'Sony WH-1000XM5',           'sony-wh-1000xm5',         'Industry-leading noise cancellation 30hr battery Multipoint connection',                       999.00,  1299.00, 88, 'SNY-WH1000XM5',  0.250, 1),
  (8,  1,  'Apple AirPods Pro 2',       'apple-airpods-pro-2',     'Adaptive Transparency H2 chip Personalised Spatial Audio USB-C',                               999.00,  1199.00, 76, 'APL-APP2-WHT',   0.061, 0),
  (8,  8,  'JBL Flip 6',                'jbl-flip-6',              'Portable Bluetooth speaker IP67 waterproof 12hr battery JBL Pro Sound', 299.00,   349.00, 148, 'JBL-FLIP6-BLU',  0.550, 0),
  (9,  10, 'DJI Osmo Mobile 6',         'dji-osmo-mobile-6',       '3-axis smartphone gimbal ActiveTrack 6.0 DJI Mimo app ShotGuides',                             599.00,   699.00, 43, 'DJI-OM6-GRY',    0.390, 0),
  (10, 5,  'Levis 511 Slim Jeans',      'levis-511-slim-jeans',    'Classic slim fit dark indigo wash stretch comfort denim 5-pocket style',                       199.00,   249.00, 195, 'LVI-511-32x32',  0.650, 0),
  (10, 4,  'Nike Air Force 1 Low',      'nike-air-force-1-low',    'Classic court style premium leather upper perforated toe box iconic look',                     399.00,   449.00, 118, 'NIK-AF1-WHT-10', 0.900, 1),
  (11, 13, 'Zara Floral Midi Dress',    'zara-floral-midi-dress',  'Elegant floral print flowing silhouette V-neckline flutter sleeves',                           249.00,   299.00,  96, 'ZRA-FMD-BLU-M',  0.400, 0),
  (12, 11, 'Instant Pot Duo 7-in-1',   'instant-pot-duo-7in1',    'Pressure cooker slow cooker rice cooker steamer saute yogurt maker',                           349.00,   399.00,  68, 'INP-DUO7-6QT',   5.200, 1),
  (12, 12, 'Ninja Air Fryer XL',        'ninja-air-fryer-xl',      '5.5L 4-in-1 digital display wide temperature range non-stick basket',                          249.00,   299.00,  82, 'NJA-AF-XL-BLK',  4.100, 0),
  (13, 6,  'IKEA BILLY Bookcase',       'ikea-billy-bookcase',     'Classic adjustable shelves white finish 80x28x202cm flat-pack',                                299.00,   349.00,  57, 'IKE-BIL-WHT',   25.000, 0),
  (4,  NULL,'Clean Code',               'clean-code-book',         'Robert C. Martin — A Handbook of Agile Software Craftsmanship',                                 89.00,    99.00, 495, 'BK-CLEANCODE',   0.500, 0),
  (4,  NULL,'System Design Interview',  'system-design-interview', 'Alex Xu — Vol 1 and 2 bundle the most read system design prep guide',                           99.00,   120.00, 395, 'BK-SYSDESIGN',   0.900, 0),
  (14, 14, 'Yonex Nanoflare 700',       'yonex-nanoflare-700',     'Aggressive attacking frame isometric head shape 4U-G5 extra slim shaft',                       450.00,   499.00,  53, 'YNX-NF700-4UG5', 0.083, 0),
  (15, 4,  'Nike React Infinity Run',   'nike-react-infinity-run', 'Maximum cushioning Flyknit upper React foam midsole rocker geometry',                           499.00,   549.00, 108, 'NIK-RIR-WHT-10', 0.310, 0);

-- Product images
INSERT INTO PRODUCT_IMAGES (product_id, url, alt_text, is_primary) VALUES
  (1,  'https://picsum.photos/seed/ip15pro/400/400',    'iPhone 15 Pro',          1),
  (2,  'https://picsum.photos/seed/s24ultra/400/400',   'Samsung S24 Ultra',      1),
  (3,  'https://picsum.photos/seed/op12/400/400',       'OnePlus 12',             1),
  (4,  'https://picsum.photos/seed/mbpm3pro/400/400',   'MacBook Pro M3 Pro',     1),
  (5,  'https://picsum.photos/seed/dellxps15/400/400',  'Dell XPS 15',            1),
  (6,  'https://picsum.photos/seed/tpx1c/400/400',      'ThinkPad X1 Carbon',     1),
  (7,  'https://picsum.photos/seed/wh1000xm5/400/400',  'Sony WH-1000XM5',        1),
  (8,  'https://picsum.photos/seed/app2/400/400',       'AirPods Pro 2',          1),
  (9,  'https://picsum.photos/seed/jblflip6/400/400',   'JBL Flip 6',             1),
  (10, 'https://picsum.photos/seed/djiosmo6/400/400',   'DJI Osmo Mobile 6',      1),
  (11, 'https://picsum.photos/seed/levis511/400/400',   'Levis 511 Slim Jeans',   1),
  (12, 'https://picsum.photos/seed/nikeaf1low/400/400', 'Nike Air Force 1',       1),
  (13, 'https://picsum.photos/seed/zarafloral/400/400', 'Zara Floral Midi Dress', 1),
  (14, 'https://picsum.photos/seed/instapot7/400/400',  'Instant Pot Duo',        1),
  (15, 'https://picsum.photos/seed/ninjaxl/400/400',    'Ninja Air Fryer XL',     1),
  (16, 'https://picsum.photos/seed/ikeabilly/400/400',  'IKEA BILLY Bookcase',    1),
  (17, 'https://picsum.photos/seed/cleancode/400/400',  'Clean Code Book',        1),
  (18, 'https://picsum.photos/seed/sysdesign2/400/400', 'System Design Interview',1),
  (19, 'https://picsum.photos/seed/yonexnf7/400/400',   'Yonex Nanoflare 700',   1),
  (20, 'https://picsum.photos/seed/nikereact/400/400',  'Nike React Infinity Run',1);

-- Product attributes
INSERT INTO PRODUCT_ATTRIBUTES (product_id, attr_name, attr_value) VALUES
  (1,'Storage','256GB'),(1,'RAM','8GB'),(1,'Display','6.1 inch Super Retina XDR'),(1,'OS','iOS 17'),
  (2,'Storage','512GB'),(2,'RAM','12GB'),(2,'Display','6.8 inch Dynamic AMOLED'),(2,'Battery','5000mAh'),
  (4,'CPU','Apple M3 Pro'),(4,'RAM','18GB Unified'),(4,'Storage','512GB SSD'),(4,'Display','14.2 inch XDR'),
  (7,'Driver','40mm'),(7,'Frequency','4Hz-40000Hz'),(7,'Battery','30 hours'),(7,'Connectivity','Bluetooth 5.2'),
  (14,'Capacity','6 Quart'),(14,'Programs','7-in-1'),(14,'Power','1000W'),(14,'Material','Stainless Steel');

-- Coupons
INSERT INTO COUPONS (code, description, type, discount_value, min_order_amt, max_discount, expires_at, max_uses) VALUES
  ('WELCOME10', '10% off your first order',          'percentage', 10.00,    0.00,  500.00, '2027-12-31', 1000),
  ('SUMMER20',  '20% off summer sale',               'percentage', 20.00,  200.00,  800.00, '2027-08-31',  500),
  ('FLASH50',   '50% flash sale limited time',       'percentage', 50.00, 1000.00, 2000.00, '2027-12-31',   50),
  ('VIP30',     'VIP member 30% discount',           'percentage', 30.00,  500.00, 1500.00, '2027-12-31',  200),
  ('STUDENT15', 'Student discount 15% off',          'percentage', 15.00,  100.00,  300.00, '2027-12-31',  300),
  ('FLAT100',   'AED 100 off on orders above 500',   'fixed',     100.00,  500.00,    NULL, '2027-12-31',  400),
  ('TECH500',   'AED 500 off on electronics > 5000', 'fixed',     500.00, 5000.00,    NULL, '2027-12-31',  100);

-- ================================================================
-- DEMO ORDERS (for analytics views to show real data)
-- ================================================================

-- Alice: iPhone + MacBook → delivered
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (2,1,14998.00,0,0,749.90,15747.90,'delivered','Express');
SET @o1=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o1,1,1,4999.00),(@o1,4,1,9999.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o1,'credit_card','completed',15747.90,NOW());

-- Bob: Sony + JBL → delivered
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (3,2,1298.00,0,20,65.90,1383.90,'delivered','Standard');
SET @o2=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o2,7,1,999.00),(@o2,9,1,299.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o2,'paypal','completed',1383.90,NOW());

-- Carol: Zara dress + Clean Code → delivered
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (4,3,338.00,33.80,10,15.21,329.41,'delivered','Standard');
SET @o3=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o3,13,1,249.00),(@o3,17,1,89.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o3,'cash_on_delivery','completed',329.41,NOW());

-- Dave: Yonex + Nike Run → shipped
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method,tracking_no)
VALUES (5,4,949.00,0,20,48.45,1017.45,'shipped','Standard','TRK-2026-004422');
SET @o4=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o4,19,1,450.00),(@o4,20,1,499.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o4,'credit_card','completed',1017.45,NOW());

-- Eve: MacBook + System Design → delivered
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (6,5,10098.00,0,0,504.90,10602.90,'delivered','Express');
SET @o5=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o5,4,1,9999.00),(@o5,18,1,99.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o5,'bank_transfer','completed',10602.90,NOW());

-- Frank: Instant Pot + Ninja → confirmed
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (7,6,598.00,59.80,20,27.91,586.11,'confirmed','Standard');
SET @o6=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o6,14,1,349.00),(@o6,15,1,249.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o6,'debit_card','completed',586.11,NOW());

-- Alice: 2nd order — Nike + Levis → delivered
INSERT INTO ORDERS (user_id,address_id,subtotal,discount_amt,shipping_fee,tax_amt,total_amount,status,shipping_method)
VALUES (2,1,598.00,0,10,30.40,638.40,'delivered','Standard');
SET @o7=LAST_INSERT_ID();
INSERT INTO ORDER_ITEMS(order_id,product_id,quantity,unit_price) VALUES(@o7,12,1,399.00),(@o7,11,1,199.00);
INSERT INTO PAYMENTS(order_id,method,status,amount,paid_at) VALUES(@o7,'apple_pay','completed',638.40,NOW());

-- Reviews for delivered orders
INSERT INTO REVIEWS (user_id,product_id,order_id,rating,title,comment) VALUES
  (2,1,@o1,5,'Absolutely stunning phone','The titanium body feels incredible. Camera quality blows everything else away.'),
  (2,4,@o1,5,'Best laptop ever made','M3 Pro handles everything instantly. Battery lasts all day. Display is breathtaking.'),
  (3,7,@o2,5,'Worth every single dirham','Industry-leading for a reason. Silence on the metro is priceless. 30hrs battery is accurate.'),
  (3,9,@o2,4,'Punchy bass great speaker','Surprisingly loud for its size. IP67 means pool parties are fine. Bass could be deeper.'),
  (4,13,@o3,4,'Beautiful dress true to size','Quality fabric, excellent stitching. Runs slightly large so size down.'),
  (4,17,@o3,5,'Changed how I write code','Every CS student and developer must read this. Dense but worth every page.'),
  (6,4,@o5,5,'Eve loves this MacBook','Second MacBook in our household. Speed difference from Intel is unreal.'),
  (6,18,@o5,5,'Best system design prep','Used this for Google interviews. Got the offer. 5 stars.'),
  (2,12,@o7,5,'Classic sneaker perfection','Timeless design. Premium leather. Goes with everything. True to size.'),
  (2,11,@o7,4,'Solid daily jeans','Great fit and stretch. Colour holds after many washes. Good value.');

-- Wishlists
INSERT INTO WISHLISTS (user_id, product_id) VALUES
  (2,2),(2,7),(3,1),(3,4),(4,8),(5,1),(5,10),(6,14),(7,4),(7,7);

-- ================================================================
-- COMPLEX QUERIES (commented reference for assignment report)
-- ================================================================

-- Q1: Correlated subquery — products priced above their category average
-- SELECT p.product_id, p.name, p.price, c.name AS category,
--   (SELECT ROUND(AVG(p2.price),2) FROM PRODUCTS p2 WHERE p2.category_id=p.category_id) AS cat_avg
-- FROM PRODUCTS p JOIN CATEGORIES c ON p.category_id=c.category_id
-- WHERE p.price > (SELECT AVG(p3.price) FROM PRODUCTS p3 WHERE p3.category_id=p.category_id)
-- ORDER BY c.name, p.price DESC;

-- Q2: Nested subquery — customers who spent above avg user spend
-- SELECT u.full_name, u.email, SUM(o.total_amount) AS total_spent
-- FROM USERS u JOIN ORDERS o ON u.user_id=o.user_id WHERE o.status='delivered'
-- GROUP BY u.user_id
-- HAVING SUM(o.total_amount) > (
--   SELECT AVG(s.tot) FROM (SELECT SUM(total_amount) AS tot FROM ORDERS
--   WHERE status='delivered' GROUP BY user_id) s
-- );

-- Q3: Window function — rank products by revenue within each category
-- SELECT product_name, category_name, revenue,
--   RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS cat_rank
-- FROM vw_revenue_by_category;

-- Q4: EXISTS — users who placed an order but never wrote a review
-- SELECT u.user_id, u.full_name FROM USERS u
-- WHERE EXISTS (SELECT 1 FROM ORDERS o WHERE o.user_id=u.user_id)
--   AND NOT EXISTS (SELECT 1 FROM REVIEWS r WHERE r.user_id=u.user_id);

-- Q5: Multi-level join — full order breakdown with brand
-- SELECT o.order_id, u.full_name, b.name AS brand, p.name AS product,
--   oi.quantity, oi.unit_price, (oi.quantity*oi.unit_price) AS line_total
-- FROM ORDERS o JOIN USERS u ON o.user_id=u.user_id
-- JOIN ORDER_ITEMS oi ON o.order_id=oi.order_id
-- JOIN PRODUCTS p ON oi.product_id=p.product_id
-- LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
-- ORDER BY o.order_id;
