const jwt = require('jsonwebtoken');

// Checks a Firebase ID token WITHOUT needing a service-account key:
// Firebase signs tokens with Google's public certificates, so we only need your project ID.
const CERT_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
let certs = null;
let certsExpire = 0;

async function getCerts() {
  if (certs && Date.now() < certsExpire) return certs;
  const r = await fetch(CERT_URL);
  if (!r.ok) throw new Error('Could not load Firebase certificates');
  certs = await r.json();
  const m = /max-age=(\d+)/.exec(r.headers.get('cache-control') || '');
  certsExpire = Date.now() + (m ? Number(m[1]) : 3600) * 1000;
  return certs;
}

async function verifyFirebaseToken(token) {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) throw new Error('FIREBASE_PROJECT_ID is not set in server/.env');
  const decoded = jwt.decode(token, { complete: true });
  const kid = decoded && decoded.header && decoded.header.kid;
  const cert = kid && (await getCerts())[kid];
  if (!cert) throw new Error('Unknown Firebase signing key');
  const p = jwt.verify(token, cert, {
    algorithms: ['RS256'],
    audience: projectId,
    issuer: `https://securetoken.google.com/${projectId}`,
  });
  if (!p.sub) throw new Error('Invalid Firebase token');
  // Same shape as the server's own login token. Firebase users are owners (matches the app).
  return { id: p.sub, name: p.name || p.email || 'User', email: p.email || '', role: 'owner' };
}

module.exports = { verifyFirebaseToken };
