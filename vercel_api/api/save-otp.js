const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin once
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

function getFpDocId(email) {
  const clean = email.trim().toLowerCase();
  return 'fp_' + crypto.createHash('sha256').update(clean).digest('hex');
}

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { email, code } = req.body || {};

  if (!email || !code || typeof email !== 'string' || typeof code !== 'string') {
    return res.status(400).json({ error: 'Email and OTP code are required.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const docId = getFpDocId(cleanEmail);

  // Hash code before saving
  const hashedCode = crypto
    .createHash('sha256')
    .update(`${code.trim()}:${docId}`)
    .digest('hex');

  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins TTL

  // Save hashed OTP to Firestore using Admin SDK (bypasses security rules!)
  try {
    await db.collection('otp_codes').doc(docId).set({
      hashedCode: hashedCode,
      email: cleanEmail,
      expiresAt: expiresAt.toISOString(),
      attempts: 0,
      createdAt: new Date().toISOString(),
    });
  } catch (e) {
    console.error('Firestore Admin set error:', e);
    return res.status(500).json({ error: 'Failed to save OTP to database.' });
  }

  return res.status(200).json({ success: true });
};
