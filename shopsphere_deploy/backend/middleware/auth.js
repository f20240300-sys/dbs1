const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'shopsphere_dev_secret';
function authenticate(req, res, next) {
  const h = req.headers['authorization'] || '';
  if (!h.startsWith('Bearer ')) return res.status(401).json({ error: 'No token' });
  try { req.user = jwt.verify(h.slice(7), JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Invalid or expired token' }); }
}
function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') return res.status(403).json({ error: 'Admin only' });
  next();
}
module.exports = { authenticate, requireAdmin, JWT_SECRET };
