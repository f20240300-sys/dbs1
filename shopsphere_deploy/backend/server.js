require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');
const db      = require('./db/connection');

const app = express();
app.use(cors({ origin: ['https://292akhil2929-cmyk.github.io', 'http://localhost:3000', 'http://localhost:5500'], credentials: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend/public')));

// ── Routes ──────────────────────────────────────────────────
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/cart',     require('./routes/cart'));
app.use('/api/orders',   require('./routes/orders'));

const { reviewRouter, wishRouter, userRouter } = require('./routes/misc');
app.use('/api/reviews',   reviewRouter);
app.use('/api/wishlist',  wishRouter);
app.use('/api/users',     userRouter);

// ── Shorthand routes ────────────────────────────────────────
app.get('/api/categories', async (req,res) => {
  try { const [r]=await db.query('SELECT category_id,name,parent_id FROM CATEGORIES WHERE is_active=1 ORDER BY parent_id,name'); res.json(r); }
  catch(e) { res.status(500).json({error:e.message}); }
});

app.get('/api/coupons/validate/:code', async (req,res) => {
  try {
    const [[c]] = await db.query(
      `SELECT coupon_id,code,type,discount_value,min_order_amt,max_discount,expires_at
       FROM COUPONS WHERE code=? AND is_active=1 AND expires_at>=CURDATE() AND used_count<max_uses`,
      [req.params.code.toUpperCase()]
    );
    if (!c) return res.status(404).json({ valid:false, error:'Invalid or expired coupon' });
    res.json({ valid:true, ...c });
  } catch(e) { res.status(500).json({error:e.message}); }
});

// ── SPA fallback ────────────────────────────────────────────
app.get('*', (req,res) => res.sendFile(path.join(__dirname,'../frontend/public/index.html')));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n🚀  ShopSphere running → http://localhost:${PORT}`);
  console.log(`    API → http://localhost:${PORT}/api\n`);
});
