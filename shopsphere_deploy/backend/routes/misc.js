// ── REVIEWS ────────────────────────────────────────────────
const reviewRouter = require('express').Router();
const db = require('../db/connection');
const { authenticate } = require('../middleware/auth');

reviewRouter.get('/:product_id', async (req,res) => {
  try {
    const [rows] = await db.query(
      `SELECT r.review_id,r.rating,r.title,r.comment,r.helpful_count,r.is_verified,r.created_at,
              u.full_name AS reviewer
       FROM REVIEWS r JOIN USERS u ON r.user_id=u.user_id
       WHERE r.product_id=? ORDER BY r.created_at DESC`,
      [req.params.product_id]
    );
    res.json(rows);
  } catch(e) { res.status(500).json({error:e.message}); }
});

reviewRouter.post('/', authenticate, async (req,res) => {
  const { product_id, order_id, rating, title, comment } = req.body;
  if (!product_id||!order_id||!rating) return res.status(400).json({error:'product_id, order_id, rating required'});
  const r=+rating;
  if(r<1||r>5) return res.status(400).json({error:'Rating 1-5'});
  try {
    await db.query(
      'INSERT INTO REVIEWS(user_id,product_id,order_id,rating,title,comment) VALUES(?,?,?,?,?,?)',
      [req.user.user_id,product_id,order_id,r,title||null,comment||null]
    );
    res.status(201).json({message:'Review submitted'});
  } catch(e) {
    if(e.code==='ER_DUP_ENTRY') return res.status(409).json({error:'Already reviewed'});
    if(e.sqlState==='45000')    return res.status(403).json({error:e.message});
    res.status(500).json({error:e.message});
  }
});

// ── WISHLISTS ───────────────────────────────────────────────
const wishRouter = require('express').Router();

wishRouter.get('/', authenticate, async (req,res) => {
  try {
    const [rows] = await db.query(
      `SELECT w.wishlist_id,w.added_at,p.product_id,p.name,p.price,p.avg_rating,
              b.name AS brand_name, pi.url AS image
       FROM WISHLISTS w
       JOIN PRODUCTS p ON w.product_id=p.product_id
       LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
       LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
       WHERE w.user_id=? ORDER BY w.added_at DESC`,
      [req.user.user_id]
    );
    res.json(rows);
  } catch(e) { res.status(500).json({error:e.message}); }
});

wishRouter.post('/', authenticate, async (req,res) => {
  const { product_id } = req.body;
  if(!product_id) return res.status(400).json({error:'product_id required'});
  try {
    await db.query('INSERT IGNORE INTO WISHLISTS(user_id,product_id) VALUES(?,?)',[req.user.user_id,product_id]);
    res.json({message:'Added to wishlist'});
  } catch(e) { res.status(500).json({error:e.message}); }
});

wishRouter.delete('/:id', authenticate, async (req,res) => {
  try {
    await db.query('DELETE FROM WISHLISTS WHERE wishlist_id=? AND user_id=?',[req.params.id,req.user.user_id]);
    res.json({message:'Removed'});
  } catch(e) { res.status(500).json({error:e.message}); }
});

// ── USERS / ADMIN ───────────────────────────────────────────
const userRouter = require('express').Router();
const { requireAdmin } = require('../middleware/auth');

userRouter.get('/profile', authenticate, async (req,res) => {
  try {
    const [[u]] = await db.query(
      'SELECT user_id,email,full_name,phone,role,created_at,last_login FROM USERS WHERE user_id=?',
      [req.user.user_id]
    );
    const [addrs] = await db.query('SELECT * FROM ADDRESSES WHERE user_id=? ORDER BY is_default DESC',[req.user.user_id]);
    res.json({...u, addresses:addrs});
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.post('/addresses', authenticate, async (req,res) => {
  const { label, full_name, street, city, state, country, postal_code, is_default } = req.body;
  if(!full_name||!street||!city) return res.status(400).json({error:'full_name, street, city required'});
  try {
    const [r] = await db.query(
      'INSERT INTO ADDRESSES(user_id,label,full_name,street,city,state,country,postal_code,is_default) VALUES(?,?,?,?,?,?,?,?,?)',
      [req.user.user_id,label||'Home',full_name,street,city,state||null,country||'UAE',postal_code||null,is_default?1:0]
    );
    res.status(201).json({address_id:r.insertId,message:'Address added'});
  } catch(e) { res.status(500).json({error:e.message}); }
});

// Admin endpoints
userRouter.get('/admin/dashboard', authenticate, requireAdmin, async (req,res) => {
  try {
    const [[stats]] = await db.query('CALL sp_dashboard_stats()');
    // sp returns result set as rows[0] in mysql2
    const [rows] = await db.query('CALL sp_dashboard_stats()');
    res.json(rows[0][0]);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.get('/admin/top-products', authenticate, requireAdmin, async (req,res) => {
  try {
    const [rows] = await db.query('CALL sp_top_selling_products(?)',[parseInt(req.query.limit)||10]);
    res.json(rows[0]);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.get('/admin/revenue-by-category', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query('SELECT * FROM vw_revenue_by_category ORDER BY revenue DESC');
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.get('/admin/low-stock', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query('SELECT * FROM vw_low_stock');
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.get('/admin/customer-ltv', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query('SELECT * FROM vw_customer_ltv ORDER BY lifetime_value DESC');
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

// Correlated subquery — products above category avg price
userRouter.get('/admin/above-avg-price', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query(
      `SELECT p.product_id,p.name,p.price,c.name AS category,
              ROUND((SELECT AVG(p2.price) FROM PRODUCTS p2 WHERE p2.category_id=p.category_id),2) AS cat_avg_price
       FROM PRODUCTS p JOIN CATEGORIES c ON p.category_id=c.category_id
       WHERE p.price > (SELECT AVG(p3.price) FROM PRODUCTS p3 WHERE p3.category_id=p.category_id)
         AND p.is_active=1
       ORDER BY c.name,p.price DESC`
    );
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

// Nested subquery — VIP customers above avg spend
userRouter.get('/admin/vip-customers', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query(
      `SELECT u.user_id,u.full_name,u.email,
              COUNT(o.order_id) AS order_count,
              ROUND(SUM(o.total_amount),2) AS total_spent
       FROM USERS u JOIN ORDERS o ON u.user_id=o.user_id
       WHERE o.status='delivered'
       GROUP BY u.user_id,u.full_name,u.email
       HAVING SUM(o.total_amount) > (
         SELECT AVG(s.tot) FROM (
           SELECT SUM(total_amount) AS tot FROM ORDERS
           WHERE status='delivered' GROUP BY user_id
         ) s
       )
       ORDER BY total_spent DESC`
    );
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.get('/admin/audit-log', authenticate, requireAdmin, async (req,res) => {
  try {
    const [r] = await db.query('SELECT * FROM AUDIT_LOG ORDER BY changed_at DESC LIMIT 100');
    res.json(r);
  } catch(e) { res.status(500).json({error:e.message}); }
});

userRouter.post('/admin/restock', authenticate, requireAdmin, async (req,res) => {
  const { product_id, quantity } = req.body;
  if(!product_id||!quantity) return res.status(400).json({error:'product_id and quantity required'});
  try {
    const [rows] = await db.query('CALL sp_restock_product(?,?,?)',[+product_id,+quantity,req.user.user_id]);
    res.json(rows[0][0]);
  } catch(e) { res.status(500).json({error:e.message}); }
});

module.exports = { reviewRouter, wishRouter, userRouter };
