const router = require('express').Router();
const db = require('../db/connection');
const { authenticate } = require('../middleware/auth');

router.get('/', authenticate, async (req,res) => {
  try {
    const [items] = await db.query(
      `SELECT ci.cart_id,ci.quantity,ci.added_at,
              p.product_id,p.name,p.price,p.compare_price,p.stock_qty,
              b.name AS brand_name,
              pi.url AS image
       FROM CART_ITEMS ci
       JOIN PRODUCTS p ON ci.product_id=p.product_id
       LEFT JOIN BRANDS b ON p.brand_id=b.brand_id
       LEFT JOIN PRODUCT_IMAGES pi ON pi.product_id=p.product_id AND pi.is_primary=1
       WHERE ci.user_id=? ORDER BY ci.added_at DESC`,
      [req.user.user_id]
    );
    const subtotal = items.reduce((s,i)=>s+parseFloat(i.price)*i.quantity,0);
    res.json({ items, subtotal:+subtotal.toFixed(2), item_count:items.reduce((s,i)=>s+i.quantity,0) });
  } catch(e) { res.status(500).json({error:e.message}); }
});

router.post('/', authenticate, async (req,res) => {
  const { product_id, quantity=1 } = req.body;
  if(!product_id) return res.status(400).json({error:'product_id required'});
  const qty=+quantity||1;
  try {
    const [[p]] = await db.query('SELECT stock_qty FROM PRODUCTS WHERE product_id=? AND is_active=1',[product_id]);
    if(!p)          return res.status(404).json({error:'Product not found'});
    if(p.stock_qty<qty) return res.status(400).json({error:'Insufficient stock'});
    await db.query(
      'INSERT INTO CART_ITEMS(user_id,product_id,quantity) VALUES(?,?,?) ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity)',
      [req.user.user_id,product_id,qty]
    );
    res.json({message:'Added to cart'});
  } catch(e) { res.status(500).json({error:e.message}); }
});

router.patch('/:cart_id', authenticate, async (req,res) => {
  const qty=+req.body.quantity;
  if(!qty||qty<1) return res.status(400).json({error:'quantity >= 1 required'});
  try {
    const [r]=await db.query('UPDATE CART_ITEMS SET quantity=? WHERE cart_id=? AND user_id=?',[qty,req.params.cart_id,req.user.user_id]);
    if(!r.affectedRows) return res.status(404).json({error:'Cart item not found'});
    res.json({message:'Updated'});
  } catch(e) { res.status(500).json({error:e.message}); }
});

router.delete('/:cart_id', authenticate, async (req,res) => {
  try { await db.query('DELETE FROM CART_ITEMS WHERE cart_id=? AND user_id=?',[req.params.cart_id,req.user.user_id]); res.json({message:'Removed'}); }
  catch(e) { res.status(500).json({error:e.message}); }
});

router.delete('/', authenticate, async (req,res) => {
  try { await db.query('DELETE FROM CART_ITEMS WHERE user_id=?',[req.user.user_id]); res.json({message:'Cart cleared'}); }
  catch(e) { res.status(500).json({error:e.message}); }
});

module.exports = router;
