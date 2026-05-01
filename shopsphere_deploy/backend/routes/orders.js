const router = require('express').Router();
const db = require('../db/connection');
const { authenticate, requireAdmin } = require('../middleware/auth');

// POST /api/orders/checkout — invokes stored procedure
router.post('/checkout', authenticate, async (req, res) => {
  const { address_id, coupon_code, payment_method='cash_on_delivery', shipping_method='Standard' } = req.body;
  if (!address_id) return res.status(400).json({ error: 'address_id required' });
  const conn = await db.getConnection();
  try {
    await conn.query('SET @oid=0,@msg=""');
    await conn.query('CALL sp_place_order(?,?,?,?,?,@oid,@msg)', [
      req.user.user_id, +address_id, coupon_code||null, payment_method, shipping_method
    ]);
    const [[out]] = await conn.query('SELECT @oid AS order_id, @msg AS message');
    if (out.order_id <= 0) return res.status(400).json({ error: out.message });
    res.status(201).json({ order_id: out.order_id, message: out.message });
  } catch(e) { res.status(500).json({ error: e.message }); }
  finally { conn.release(); }
});

// GET /api/orders — user's own orders
router.get('/', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT o.order_id,o.status,o.total_amount,o.ordered_at,o.tracking_no,o.shipping_method,
              COUNT(oi.item_id) AS item_count,
              py.method AS payment_method, py.status AS payment_status
       FROM ORDERS o
       JOIN ORDER_ITEMS oi ON o.order_id=oi.order_id
       LEFT JOIN PAYMENTS py ON o.order_id=py.order_id
       WHERE o.user_id=?
       GROUP BY o.order_id,o.status,o.total_amount,o.ordered_at,o.tracking_no,o.shipping_method,py.method,py.status
       ORDER BY o.ordered_at DESC`,
      [req.user.user_id]
    );
    res.json(rows);
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// GET /api/orders/admin/all (admin)
router.get('/admin/all', authenticate, requireAdmin, async (req, res) => {
  try {
    const { status, page=1, limit=30 } = req.query;
    const off = (parseInt(page)-1)*parseInt(limit);
    const conds=[], params=[];
    if (status){ conds.push('o.status=?'); params.push(status); }
    const where = conds.length?'WHERE '+conds.join(' AND '):'';
    const [rows] = await db.query(
      `SELECT o.order_id,o.status,o.total_amount,o.ordered_at,o.tracking_no,
              u.full_name AS customer, u.email,
              py.method AS payment_method, py.status AS payment_status,
              COUNT(oi.item_id) AS item_count
       FROM ORDERS o
       JOIN USERS u ON o.user_id=u.user_id
       JOIN ORDER_ITEMS oi ON o.order_id=oi.order_id
       LEFT JOIN PAYMENTS py ON o.order_id=py.order_id
       ${where}
       GROUP BY o.order_id,o.status,o.total_amount,o.ordered_at,o.tracking_no,u.full_name,u.email,py.method,py.status
       ORDER BY o.ordered_at DESC LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), off]
    );
    res.json(rows);
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// GET /api/orders/:id
router.get('/:id', authenticate, async (req, res) => {
  try {
    const isAdmin = req.user.role==='admin';
    const [[o]] = await db.query(
      `SELECT o.*,
              a.label AS addr_label,a.street,a.city,a.country,a.postal_code,
              cp.code AS coupon_code,cp.discount_value,cp.type AS coupon_type,
              py.method AS payment_method,py.status AS payment_status,py.paid_at
       FROM ORDERS o
       JOIN ADDRESSES a ON o.address_id=a.address_id
       LEFT JOIN COUPONS  cp ON o.coupon_id=cp.coupon_id
       LEFT JOIN PAYMENTS py ON o.order_id=py.order_id
       WHERE o.order_id=? AND (o.user_id=? OR ?=TRUE)`,
      [req.params.id, req.user.user_id, isAdmin]
    );
    if (!o) return res.status(404).json({ error:'Order not found' });
    const [items] = await db.query(
      `SELECT oi.quantity,oi.unit_price,(oi.quantity*oi.unit_price) AS line_total,
              p.product_id,p.name,b.name AS brand_name,pi.url AS image
       FROM ORDER_ITEMS oi
       JOIN PRODUCTS p ON oi.product_id=p.product_id
       LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
       LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
       WHERE oi.order_id=?`,
      [req.params.id]
    );
    res.json({ ...o, items });
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// PATCH /api/orders/:id/status (admin)
router.patch('/:id/status', authenticate, requireAdmin, async (req, res) => {
  const valid=['pending','confirmed','processing','shipped','delivered','cancelled','refunded'];
  if (!valid.includes(req.body.status)) return res.status(400).json({ error:'Invalid status' });
  try {
    await db.query('UPDATE ORDERS SET status=? WHERE order_id=?',[req.body.status,req.params.id]);
    res.json({ message:`Order ${req.params.id} → ${req.body.status}` });
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// PATCH /api/orders/:id/tracking (admin)
router.patch('/:id/tracking', authenticate, requireAdmin, async (req, res) => {
  const { tracking_no } = req.body;
  if (!tracking_no) return res.status(400).json({ error:'tracking_no required' });
  try {
    await db.query('UPDATE ORDERS SET tracking_no=?,status="shipped" WHERE order_id=?',[tracking_no,req.params.id]);
    res.json({ message:'Tracking updated' });
  } catch(e) { res.status(500).json({ error:e.message }); }
});

module.exports = router;
