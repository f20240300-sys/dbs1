const router = require('express').Router();
const db     = require('../db/connection');
const { authenticate, requireAdmin } = require('../middleware/auth');

// GET /api/products
router.get('/', async (req, res) => {
  try {
    let { search, category_id, brand_id, min_price, max_price, sort, featured, page, limit } = req.query;
    page  = Math.max(1, parseInt(page)||1);
    limit = Math.min(50, Math.max(1, parseInt(limit)||12));
    const off = (page-1)*limit, conds=['p.is_active=1'], params=[];
    if (search)      { conds.push('(p.name LIKE ? OR p.description LIKE ?)'); params.push(`%${search}%`,`%${search}%`); }
    if (category_id) { conds.push('p.category_id=?'); params.push(+category_id); }
    if (brand_id)    { conds.push('p.brand_id=?');    params.push(+brand_id); }
    if (min_price)   { conds.push('p.price>=?');      params.push(+min_price); }
    if (max_price)   { conds.push('p.price<=?');      params.push(+max_price); }
    if (featured==='1') { conds.push('p.is_featured=1'); }
    const where = 'WHERE '+conds.join(' AND ');
    const ord = {price_asc:'p.price ASC',price_desc:'p.price DESC',rating:'p.avg_rating DESC',newest:'p.created_at DESC',featured:'p.is_featured DESC,p.avg_rating DESC'}[sort]||'p.is_featured DESC,p.created_at DESC';
    const [[{total}]] = await db.query(`SELECT COUNT(*) AS total FROM PRODUCTS p ${where}`, params);
    const [products]  = await db.query(
      `SELECT p.product_id,p.name,p.price,p.compare_price,p.stock_qty,p.avg_rating,p.review_count,p.is_featured,
              ROUND(((p.compare_price-p.price)/p.compare_price)*100) AS discount_pct,
              c.name AS category_name, b.name AS brand_name, pi.url AS primary_image
       FROM PRODUCTS p
       JOIN CATEGORIES c ON p.category_id=c.category_id
       LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
       LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
       ${where} ORDER BY ${ord} LIMIT ? OFFSET ?`,
      [...params, limit, off]
    );
    res.json({ products, pagination:{ page, limit, total:+total, pages:Math.ceil(total/limit) } });
  } catch(e) { res.status(500).json({ error: e.message }); }
});

// GET /api/products/meta/categories
router.get('/meta/categories', async (req, res) => {
  try {
    const [r] = await db.query('SELECT category_id,name,parent_id,description FROM CATEGORIES WHERE is_active=1 ORDER BY parent_id,name');
    res.json(r);
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// GET /api/products/meta/brands
router.get('/meta/brands', async (req, res) => {
  try {
    const [r] = await db.query('SELECT brand_id,name,country FROM BRANDS WHERE is_active=1 ORDER BY name');
    res.json(r);
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// GET /api/products/:id
router.get('/:id', async (req, res) => {
  try {
    const [[p]] = await db.query(
      `SELECT p.*,c.name AS category_name,b.name AS brand_name,b.country AS brand_country,
              ROUND(((p.compare_price-p.price)/p.compare_price)*100) AS discount_pct
       FROM PRODUCTS p
       JOIN CATEGORIES c ON p.category_id=c.category_id
       LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
       WHERE p.product_id=? AND p.is_active=1`, [req.params.id]
    );
    if (!p) return res.status(404).json({ error:'Product not found' });
    const [images] = await db.query('SELECT url,alt_text,is_primary FROM PRODUCT_IMAGES WHERE product_id=? ORDER BY is_primary DESC,sort_order', [p.product_id]);
    const [attrs]  = await db.query('SELECT attr_name,attr_value FROM PRODUCT_ATTRIBUTES WHERE product_id=?', [p.product_id]);
    const [reviews]= await db.query(
      `SELECT r.rating,r.title,r.comment,r.helpful_count,r.created_at,u.full_name AS reviewer
       FROM REVIEWS r JOIN USERS u ON r.user_id=u.user_id WHERE r.product_id=? ORDER BY r.created_at DESC LIMIT 20`,
      [p.product_id]
    );
    const [similar]= await db.query(
      `SELECT p2.product_id,p2.name,p2.price,p2.avg_rating,pi.url AS primary_image
       FROM PRODUCTS p2 LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p2.product_id AND pi.is_primary=1
       WHERE p2.category_id=? AND p2.product_id!=? AND p2.is_active=1 LIMIT 4`,
      [p.category_id, p.product_id]
    );
    res.json({ ...p, images, attributes:attrs, reviews, similar });
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// POST /api/products (admin)
router.post('/', authenticate, requireAdmin, async (req, res) => {
  const { category_id, brand_id, name, description, price, compare_price, stock_qty, sku, weight_kg, is_featured } = req.body;
  if (!category_id||!name||price==null) return res.status(400).json({ error:'category_id, name, price required' });
  try {
    const [r] = await db.query(
      'INSERT INTO PRODUCTS(category_id,brand_id,name,slug,description,price,compare_price,stock_qty,sku,weight_kg,is_featured) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
      [category_id, brand_id||null, name, name.toLowerCase().replace(/\s+/g,'-'), description||'', +price, compare_price||null, +stock_qty||0, sku||null, weight_kg||null, is_featured?1:0]
    );
    res.status(201).json({ product_id:r.insertId, message:'Product created' });
  } catch(e) { res.status(500).json({ error:e.message }); }
});

// PATCH /api/products/:id (admin)
router.patch('/:id', authenticate, requireAdmin, async (req, res) => {
  const allowed=['name','description','price','compare_price','stock_qty','category_id','brand_id','is_active','is_featured','sku','weight_kg'];
  const sets=[],vals=[];
  for(const f of allowed) if(req.body[f]!==undefined){sets.push(`${f}=?`);vals.push(req.body[f]);}
  if(!sets.length) return res.status(400).json({ error:'Nothing to update' });
  vals.push(req.params.id);
  try { await db.query(`UPDATE PRODUCTS SET ${sets.join(',')} WHERE product_id=?`, vals); res.json({message:'Updated'}); }
  catch(e) { res.status(500).json({error:e.message}); }
});

// DELETE /api/products/:id (admin soft-delete)
router.delete('/:id', authenticate, requireAdmin, async (req, res) => {
  try { await db.query('UPDATE PRODUCTS SET is_active=0 WHERE product_id=?',[req.params.id]); res.json({message:'Deactivated'}); }
  catch(e) { res.status(500).json({error:e.message}); }
});

module.exports = router;
