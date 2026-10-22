require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { init, q, getPool } = require('./db');

const {
  JWT_SECRET, JWT_EXPIRES = '24h', PORT = 3000,
  ADMIN_NAME = 'Owner', ADMIN_EMAIL = 'owner@pos.com', ADMIN_PASSWORD = 'ChangeMe123!',
  SEED_DEMO = 'true',
  PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET, PAYPAL_ENV = 'sandbox', UGX_PER_USD = '3700',
} = process.env;

if (!JWT_SECRET || JWT_SECRET.length < 16) {
  console.error('Set JWT_SECRET in server/.env (at least 16 random characters).');
  process.exit(1);
}

const app = express();
app.use(cors());              // production: cors({ origin: 'https://your-site.com' })
app.use(express.json({ limit: '1mb' }));

// ───────────── helpers ─────────────
const wrap = (fn) => (req, res) => fn(req, res).catch((e) => { console.error(e); res.status(500).json({ error: 'Server error' }); });

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!t) return res.status(401).json({ error: 'Login required' });
  try { req.user = jwt.verify(t, JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Session expired. Please log in again.' }); }
}
const owner = (req, res, next) => (req.user.role === 'owner' ? next() : res.status(403).json({ error: 'Owner access only' }));

// Tiny auth guard: 10 attempts / 15 min / IP.
const attempts = new Map();
function authLimit(req, res, next) {
  const k = req.ip, now = Date.now();
  const a = (attempts.get(k) || []).filter((t) => now - t < 15 * 60 * 1000);
  if (a.length >= 10) return res.status(429).json({ error: 'Too many attempts. Try again in 15 minutes.' });
  a.push(now); attempts.set(k, a); next();
}

const isInt = (v) => Number.isInteger(v);
const METHODS = ['Cash', 'Card', 'Mobile Money', 'Bank Transfer', 'PayPal'];

// ───────────── auth ─────────────
app.post('/auth/register', authLimit, wrap(async (req, res) => {
  const { name, email, password } = req.body || {};
  if (typeof name !== 'string' || typeof email !== 'string' || typeof password !== 'string' ||
      !name.trim() || !email.trim() || password.length < 8) {
    return res.status(400).json({ error: 'Name, valid email and a password of 8+ characters required' });
  }
  const normalizedName = name.trim();
  const normalizedEmail = email.toLowerCase().trim();
  if (normalizedName.length > 100 || normalizedEmail.length > 150 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Enter a valid name and email address' });
  }
  const id = crypto.randomUUID();
  try {
    await q('INSERT INTO users (id,name,email,password_hash,role) VALUES (?,?,?,?,?)',
      [id, normalizedName, normalizedEmail, await bcrypt.hash(password, 10), 'cashier']);
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Email already used' });
    throw e;
  }
  const user = { id, name: normalizedName, email: normalizedEmail, role: 'cashier' };
  res.status(201).json({ token: jwt.sign(user, JWT_SECRET, { expiresIn: JWT_EXPIRES }), user });
}));

app.post('/auth/login', authLimit, wrap(async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  const [rows] = await q('SELECT * FROM users WHERE email = ?', [String(email).toLowerCase().trim()]);
  const u = rows[0];
  if (!u || !(await bcrypt.compare(String(password), u.password_hash))) {
    return res.status(401).json({ error: 'Wrong email or password' });
  }
  const user = { id: u.id, name: u.name, email: u.email, role: u.role };
  res.json({ token: jwt.sign(user, JWT_SECRET, { expiresIn: JWT_EXPIRES }), user });
}));

app.get('/users', auth, owner, wrap(async (_req, res) => {
  const [rows] = await q('SELECT id, name, email, role FROM users ORDER BY name');
  res.json(rows);
}));

app.post('/users', auth, owner, wrap(async (req, res) => {
  const { name, email, password, role = 'cashier' } = req.body || {};
  if (!name || !email || !password || String(password).length < 8) return res.status(400).json({ error: 'Name, email and a password of 8+ characters required' });
  if (!['owner', 'cashier'].includes(role)) return res.status(400).json({ error: 'Invalid role' });
  const id = crypto.randomUUID();
  try {
    await q('INSERT INTO users (id,name,email,password_hash,role) VALUES (?,?,?,?,?)',
      [id, name, String(email).toLowerCase().trim(), await bcrypt.hash(String(password), 10), role]);
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Email already used' });
    throw e;
  }
  res.status(201).json({ id, name, email, role });
}));

// ───────────── products ─────────────
const PCOLS = 'id, name, price, stock, reorder, category, image';

app.get('/products', auth, wrap(async (_req, res) => {
  const [rows] = await q(`SELECT ${PCOLS} FROM products ORDER BY name`);
  res.json(rows);
}));

app.post('/products', auth, owner, wrap(async (req, res) => {
  const { name, price, stock, reorder = 10, category = 'Other', image = '' } = req.body || {};
  if (!name || !isInt(price) || price < 0 || !isInt(stock) || stock < 0) return res.status(400).json({ error: 'Name, price and stock are required' });
  const id = crypto.randomUUID();
  await q('INSERT INTO products (id,name,price,stock,reorder,category,image) VALUES (?,?,?,?,?,?,?)', [id, name, price, stock, reorder, category, image]);
  res.status(201).json({ id, name, price, stock, reorder, category, image });
}));

app.put('/products/:id', auth, owner, wrap(async (req, res) => {
  const allowed = ['name', 'price', 'stock', 'reorder', 'category', 'image'];
  const sets = [], vals = [];
  for (const k of allowed) if (k in req.body) { sets.push(`${k} = ?`); vals.push(req.body[k]); }
  if (!sets.length) return res.status(400).json({ error: 'Nothing to update' });
  const [r] = await q(`UPDATE products SET ${sets.join(', ')} WHERE id = ?`, [...vals, req.params.id]);
  if (!r.affectedRows) return res.status(404).json({ error: 'Product not found' });
  const [rows] = await q(`SELECT ${PCOLS} FROM products WHERE id = ?`, [req.params.id]);
  res.json(rows[0]);
}));

// ───────────── customers ─────────────
app.get('/customers', auth, wrap(async (_req, res) => {
  const [rows] = await q('SELECT id, name, phone, email FROM customers ORDER BY name');
  res.json(rows);
}));

app.post('/customers', auth, wrap(async (req, res) => {
  const { name, phone, email = '' } = req.body || {};
  if (!name || !phone) return res.status(400).json({ error: 'Name and phone are required' });
  const id = crypto.randomUUID();
  await q('INSERT INTO customers (id,name,phone,email) VALUES (?,?,?,?)', [id, name, phone, email]);
  res.status(201).json({ id, name, phone, email });
}));

// ───────────── sales (offline sync target, safe to call twice for the same sale) ─────────────
app.post('/sales', auth, wrap(async (req, res) => {
  const s = req.body || {};
  const created = new Date(s.created);
  if (!s.id || !s.receipt || !isInt(s.total) || s.total < 0 || !isInt(s.tax) || !METHODS.includes(s.method)
      || isNaN(created) || !Array.isArray(s.lines)) {
    return res.status(400).json({ error: 'Invalid sale' });
  }
  for (const l of s.lines) if (!l.productId || !isInt(l.price) || !isInt(l.qty) || l.qty <= 0) return res.status(400).json({ error: 'Invalid sale line' });

  const conn = await getPool().getConnection();
  try {
    await conn.beginTransaction();
    const [r] = await conn.query(
      'INSERT IGNORE INTO sales (id,receipt,total,tax,method,customer,user_id,paypal_ref,created_at) VALUES (?,?,?,?,?,?,?,?,?)',
      [s.id, s.receipt, s.total, s.tax, s.method, s.customer || 'Walk-in Customer', req.user.id, s.paypalRef || null, created]);
    if (r.affectedRows === 0) { await conn.rollback(); return res.status(200).json({ ok: true, duplicate: true }); }
    for (const l of s.lines) {
      await conn.query('INSERT INTO sale_items (sale_id,product_id,name,price,qty) VALUES (?,?,?,?,?)', [s.id, l.productId, l.name, l.price, l.qty]);
      await conn.query('UPDATE products SET stock = GREATEST(stock - ?, 0) WHERE id = ?', [l.qty, l.productId]);
    }
    await conn.commit();
    res.status(201).json({ ok: true });
  } catch (e) { await conn.rollback(); throw e; }
  finally { conn.release(); }
}));

app.get('/sales', auth, wrap(async (req, res) => {
  const days = Math.min(parseInt(req.query.days) || 35, 365);
  const [rows] = await q('SELECT * FROM sales WHERE created_at >= ? ORDER BY created_at DESC', [new Date(Date.now() - days * 864e5)]);
  const [items] = rows.length ? await q('SELECT * FROM sale_items WHERE sale_id IN (?)', [rows.map((r) => r.id)]) : [[]];
  const by = {};
  for (const i of items) (by[i.sale_id] ||= []).push({ productId: i.product_id, name: i.name, price: i.price, qty: i.qty });
  res.json(rows.map((r) => ({
    id: r.id, receipt: r.receipt, method: r.method, customer: r.customer, total: r.total, tax: r.tax,
    created: new Date(r.created_at).toISOString(), paypalRef: r.paypal_ref, lines: by[r.id] || [],
  })));
}));

// ───────────── PayPal ─────────────
const PP = PAYPAL_ENV === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com';

async function paypalToken() {
  const basic = Buffer.from(`${PAYPAL_CLIENT_ID}:${PAYPAL_CLIENT_SECRET}`).toString('base64');
  const r = await fetch(`${PP}/v1/oauth2/token`, {
    method: 'POST',
    headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
  });
  const j = await r.json();
  if (!r.ok) throw new Error(JSON.stringify(j));
  return j.access_token;
}

app.post('/paypal/orders', auth, async (req, res) => {
  try {
    const { amountUgx, reference, returnUrl, cancelUrl } = req.body;
    if (!Number.isFinite(amountUgx) || amountUgx <= 0) return res.status(400).json({ error: 'Invalid amount' });
    const usd = (amountUgx / Number(UGX_PER_USD)).toFixed(2);
    if (Number(usd) < 0.01) return res.status(400).json({ error: 'Amount too small for PayPal' });
    const token = await paypalToken();
    const r = await fetch(`${PP}/v2/checkout/orders`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'PayPal-Request-Id': reference },
      body: JSON.stringify({
        intent: 'CAPTURE',
        purchase_units: [{ reference_id: reference, description: 'POS sale', amount: { currency_code: 'USD', value: usd } }],
        payment_source: { paypal: { experience_context: { return_url: returnUrl, cancel_url: cancelUrl, user_action: 'PAY_NOW', shipping_preference: 'NO_SHIPPING' } } },
      }),
    });
    const j = await r.json();
    if (!r.ok) return res.status(r.status).json({ error: j.message || 'PayPal error', details: j });
    const link = (j.links || []).find((l) => ['payer-action', 'approve'].includes(l.rel));
    if (!link) return res.status(502).json({ error: 'No approval link from PayPal' });
    res.json({ id: j.id, approveUrl: link.href, usd: Number(usd) });
  } catch (e) { console.error(e); res.status(500).json({ error: 'PayPal order failed' }); }
});

app.post('/paypal/orders/:id/capture', auth, async (req, res) => {
  try {
    const token = await paypalToken();
    const r = await fetch(`${PP}/v2/checkout/orders/${encodeURIComponent(req.params.id)}/capture`, {
      method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    });
    const j = await r.json();
    if (!r.ok) return res.status(r.status).json({ status: 'FAILED', error: 'Customer has not approved the payment yet', details: j });
    const cap = j.purchase_units?.[0]?.payments?.captures?.[0];
    res.json({ status: j.status, captureId: cap?.id, amount: cap?.amount });
  } catch (e) { console.error(e); res.status(500).json({ error: 'PayPal capture failed' }); }
});

// ───────────── first-run setup ─────────────
async function firstRun() {
  const [[u]] = await q('SELECT COUNT(*) n FROM users');
  if (u.n === 0) {
    await q('INSERT INTO users (id,name,email,password_hash,role) VALUES (?,?,?,?,"owner")',
      [crypto.randomUUID(), ADMIN_NAME, ADMIN_EMAIL.toLowerCase(), await bcrypt.hash(ADMIN_PASSWORD, 10)]);
    console.log(`Created owner account: ${ADMIN_EMAIL}  (change this password!)`);
  }
  if (SEED_DEMO === 'true') {
    const [[p]] = await q('SELECT COUNT(*) n FROM products');
    if (p.n === 0) {
      const demo = [['Coca Cola 500ml', 2500, 50, 20, 'Drinks', 'assets/images/coke.png'], ['Sprite 500ml', 2500, 40, 20, 'Drinks', 'assets/images/sprite.png'],
        ['Water 500ml', 1500, 100, 30, 'Drinks', 'assets/images/water.png'], ['Bread', 3000, 30, 10, 'Food', 'assets/images/bread.png'], ['Chips', 2000, 45, 15, 'Snacks', 'assets/images/chips.png']];
      for (const d of demo) await q('INSERT INTO products (id,name,price,stock,reorder,category,image) VALUES (?,?,?,?,?,?,?)', [crypto.randomUUID(), ...d]);
      const cust = [['John Mwangi', '+256 700 123 456'], ['Sarah Nakato', '+256 772 987 654'], ['David Kato', '+256 703 456 789'], ['Aisha Namuindwa', '+256 751 234 567'], ['Peter Ssemanda', '+256 787 654 321']];
      for (const c of cust) await q('INSERT INTO customers (id,name,phone) VALUES (?,?,?)', [crypto.randomUUID(), ...c]);
      console.log('Added demo products and customers.');
    }
  }
}

init()
  .then(firstRun)
  .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`POS server running on port ${PORT} (PayPal ${PAYPAL_ENV}) – MySQL connected`)))
  .catch((e) => { console.error('Startup failed:', e.code || '', e.message, '\nIs MySQL started in XAMPP, and are the DB_* values in .env correct?'); process.exit(1); });
