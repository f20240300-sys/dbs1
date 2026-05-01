# ShopSphere — Full-Stack E-Commerce Platform
### CS F212 Database Systems | BITS Pilani Dubai | Group of 6

---

## 🗄️ Database Summary (Full Marks Coverage)

| Feature | Count | Details |
|---------|-------|---------|
| Tables | **15** | CATEGORIES, USERS, ADDRESSES, BRANDS, PRODUCTS, PRODUCT_IMAGES, PRODUCT_ATTRIBUTES, COUPONS, ORDERS, ORDER_ITEMS, PAYMENTS, REVIEWS, CART_ITEMS, WISHLISTS, AUDIT_LOG |
| Views | **5** | vw_product_catalog, vw_order_summary, vw_revenue_by_category, vw_low_stock, vw_customer_ltv |
| Stored Functions | **5** | fn_apply_coupon, fn_cart_subtotal, fn_validate_coupon, fn_customer_order_count, fn_shipping_fee |
| Triggers | **12** | Stock control, rating updates, coupon tracking, audit logging, address defaults, slug generation |
| Stored Procedures | **7** | sp_place_order, sp_dashboard_stats, sp_top_selling_products, sp_user_order_history, sp_restock_product, sp_monthly_revenue, sp_search_products |
| Complex Queries | **5** | Correlated subquery, nested subquery, window functions, EXISTS, multi-level join |
| Normalization | **BCNF** | Brands extracted, addresses separated, images in own table, attributes in EAV table |

---

## 📋 Table Descriptions

1. **CATEGORIES** — Self-referencing hierarchy (parent/sub categories)
2. **USERS** — Customers, admins, vendors with bcrypt-hashed passwords
3. **ADDRESSES** — Separated from USERS (satisfies 2NF, removes partial deps)
4. **BRANDS** — Extracted from PRODUCTS (removes transitive dependency → BCNF)
5. **PRODUCTS** — Core product table with FULLTEXT index for search
6. **PRODUCT_IMAGES** — Multi-valued attribute in own table (satisfies 1NF)
7. **PRODUCT_ATTRIBUTES** — EAV table for flexible specs (RAM, Color, Size...)
8. **COUPONS** — Supports percentage and fixed-amount discounts
9. **ORDERS** — Master order record with status tracking
10. **ORDER_ITEMS** — Unit price snapshot (prevents transitive dependency)
11. **PAYMENTS** — Separated from ORDERS (different entity, 1:1)
12. **REVIEWS** — Linked to orders for verified-purchase enforcement
13. **CART_ITEMS** — Temporary pre-checkout session storage
14. **WISHLISTS** — Saved items for future purchase
15. **AUDIT_LOG** — Immutable trail of INSERT/UPDATE/DELETE on key tables

---

## 🔧 Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | MySQL 8.0+ |
| Backend | Node.js + Express |
| Auth | JWT + bcryptjs |
| Frontend | Vanilla HTML/CSS/JS (SPA) |

---

## 🚀 Setup Instructions

### Prerequisites
- MySQL 8.0+
- Node.js 18+

### Step 1 — Database Setup
```bash
# Open MySQL CLI or Workbench and run:
mysql -u root -p < backend/db/schema.sql
```

This creates the `shopsphere` database with all tables, triggers, procedures, functions, views, and seed data.

### Step 2 — Backend Setup
```bash
cd backend
cp .env.example .env
# Edit .env → set DB_PASSWORD to your MySQL root password

node server.js
```

### Step 3 — Access
Open `http://localhost:3000` in your browser.

---

## 🔑 Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@shopsphere.com | adminpass123 |
| Customer | alice@example.com | password123 |
| Customer | bob@example.com | password123 |
| Customer | carol@example.com | password123 |

Or register a new account directly in the UI.

---

## 🌐 API Reference

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/register | Register new user |
| POST | /api/auth/login | Login and get JWT |

### Products
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/products | List with search, filter, sort, pagination |
| GET | /api/products/:id | Single product with images, attrs, reviews |
| POST | /api/products | Create product (admin) |
| PATCH | /api/products/:id | Update product (admin) |
| DELETE | /api/products/:id | Soft-delete product (admin) |
| GET | /api/products/meta/categories | All categories |
| GET | /api/products/meta/brands | All brands |

### Cart
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/cart | Get user cart |
| POST | /api/cart | Add item to cart |
| PATCH | /api/cart/:cart_id | Update quantity |
| DELETE | /api/cart/:cart_id | Remove item |
| DELETE | /api/cart | Clear cart |

### Orders
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/orders/checkout | Place order (calls sp_place_order) |
| GET | /api/orders | User's order history |
| GET | /api/orders/:id | Order detail |
| GET | /api/orders/admin/all | All orders (admin) |
| PATCH | /api/orders/:id/status | Update status (admin) |
| PATCH | /api/orders/:id/tracking | Add tracking number (admin) |

### Reviews & Wishlist
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/reviews/:product_id | Product reviews |
| POST | /api/reviews | Submit review (verified buyers) |
| GET | /api/wishlist | User wishlist |
| POST | /api/wishlist | Add to wishlist |
| DELETE | /api/wishlist/:id | Remove from wishlist |

### Users & Admin
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/users/profile | User profile + addresses |
| POST | /api/users/addresses | Save address |
| GET | /api/users/admin/dashboard | KPI stats (calls sp_dashboard_stats) |
| GET | /api/users/admin/top-products | Top sellers (calls sp_top_selling_products) |
| GET | /api/users/admin/revenue-by-category | Uses vw_revenue_by_category |
| GET | /api/users/admin/low-stock | Uses vw_low_stock |
| GET | /api/users/admin/customer-ltv | Uses vw_customer_ltv |
| GET | /api/users/admin/above-avg-price | Correlated subquery |
| GET | /api/users/admin/vip-customers | Nested subquery |
| GET | /api/users/admin/audit-log | AUDIT_LOG table |
| POST | /api/users/admin/restock | Restock product (calls sp_restock_product) |

### Misc
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/categories | All active categories |
| GET | /api/coupons/validate/:code | Validate coupon |

---

## 📁 Project Structure

```
shopsphere/
├── backend/
│   ├── db/
│   │   ├── schema.sql          ← ALL DB objects (tables, views, functions, triggers, procedures, seed data)
│   │   └── connection.js       ← MySQL connection pool
│   ├── middleware/
│   │   └── auth.js             ← JWT authentication
│   ├── routes/
│   │   ├── auth.js             ← Register & login
│   │   ├── products.js         ← Products CRUD + search + filter
│   │   ├── cart.js             ← Cart management
│   │   ├── orders.js           ← Checkout via stored procedure
│   │   └── misc.js             ← Reviews, wishlists, users, admin analytics
│   ├── server.js               ← Express entry point
│   ├── package.json
│   └── .env.example
└── frontend/
    └── public/
        └── index.html          ← Complete SPA frontend
```

---

## 📊 Normalization Evidence

### 1NF
- No multi-valued attributes: PRODUCT_IMAGES and PRODUCT_ATTRIBUTES extracted into own tables
- All columns are atomic

### 2NF
- No partial dependencies: ADDRESSES separated from USERS
- ORDER_ITEMS has its own PK (item_id); unit_price is a snapshot, not derived

### 3NF
- No transitive dependencies: BRANDS extracted from PRODUCTS (product → brand_name was transitive via brand_id)
- PAYMENTS separated from ORDERS

### BCNF
- Every determinant is a candidate key in all tables
- CATEGORIES self-referencing is handled via parent_id FK, not redundant columns

---

## 🧪 Sample Complex Queries (from schema.sql)

```sql
-- Q1: Correlated subquery — products priced above category average
SELECT p.name, p.price, c.name AS category,
  (SELECT ROUND(AVG(p2.price),2) FROM PRODUCTS p2 
   WHERE p2.category_id = p.category_id) AS cat_avg
FROM PRODUCTS p JOIN CATEGORIES c ON p.category_id = c.category_id
WHERE p.price > (
  SELECT AVG(p3.price) FROM PRODUCTS p3 WHERE p3.category_id = p.category_id
);

-- Q2: Nested subquery — VIP customers above average spend
SELECT u.full_name, SUM(o.total_amount) AS total_spent
FROM USERS u JOIN ORDERS o ON u.user_id = o.user_id
WHERE o.status = 'delivered'
GROUP BY u.user_id
HAVING SUM(o.total_amount) > (
  SELECT AVG(s.tot) FROM (
    SELECT SUM(total_amount) AS tot FROM ORDERS
    WHERE status = 'delivered' GROUP BY user_id
  ) s
);

-- Q3: Window function — rank products by revenue per category
SELECT product_name, category_name, revenue,
  RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS cat_rank
FROM vw_revenue_by_category;

-- Q4: EXISTS — customers who ordered but never reviewed
SELECT u.full_name FROM USERS u
WHERE EXISTS (SELECT 1 FROM ORDERS o WHERE o.user_id = u.user_id)
  AND NOT EXISTS (SELECT 1 FROM REVIEWS r WHERE r.user_id = u.user_id);

-- Q5: Calling stored functions directly
SELECT name, price,
  fn_discounted_price(price, 20) AS after_20pct_off,
  fn_customer_order_count(2)     AS alice_orders
FROM PRODUCTS WHERE product_id = 1;
```
