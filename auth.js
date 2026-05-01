const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const db     = require('../db/connection');
const { JWT_SECRET } = require('../middleware/auth');

router.post('/register', async (req, res) => {
  const { email, password, full_name, phone } = req.body;
  if (!email || !password || !full_name)
    return res.status(400).json({ error: 'email, password, full_name required' });
  try {
    const [ex] = await db.query('SELECT user_id FROM USERS WHERE email=?', [email]);
    if (ex.length) return res.status(409).json({ error: 'Email already registered' });
    const hash = await bcrypt.hash(password, 10);
    const [r]  = await db.query(
      'INSERT INTO USERS(email,password_hash,full_name,phone) VALUES(?,?,?,?)',
      [email, hash, full_name, phone||null]
    );
    const token = jwt.sign({ user_id:r.insertId, email, full_name, role:'customer' }, JWT_SECRET, { expiresIn:'7d' });
    res.status(201).json({ token, user_id:r.insertId, full_name, email, role:'customer' });
  } catch(e) { res.status(500).json({ error: e.message }); }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  try {
    const [[u]] = await db.query(
      'SELECT user_id,email,password_hash,full_name,role,is_active FROM USERS WHERE email=?', [email]
    );
    if (!u)           return res.status(401).json({ error: 'Invalid credentials' });
    if (!u.is_active) return res.status(403).json({ error: 'Account deactivated' });
    if (!await bcrypt.compare(password, u.password_hash))
      return res.status(401).json({ error: 'Invalid credentials' });
    await db.query('UPDATE USERS SET last_login=NOW() WHERE user_id=?', [u.user_id]);
    const token = jwt.sign({ user_id:u.user_id, email:u.email, full_name:u.full_name, role:u.role }, JWT_SECRET, { expiresIn:'7d' });
    res.json({ token, user_id:u.user_id, full_name:u.full_name, email:u.email, role:u.role });
  } catch(e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
