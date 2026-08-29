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

  const { email, otp, newPassword } = req.body || {};

  if (!email || !otp || !newPassword) {
    return res.status(400).json({ error: 'Email, OTP, and new password are required.' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const docId = getFpDocId(cleanEmail);
  const docRef = db.collection('otp_codes').doc(docId);

  let doc;
  try {
    doc = await docRef.get();
  } catch (e) {
    console.error('Firestore get error:', e);
    return res.status(500).json({ error: 'Database error. Please try again.' });
  }

  if (!doc.exists) {
    return res.status(400).json({ error: 'Verification code expired or not found. Please request a new OTP.' });
  }

  const data = doc.data();
  const expiresAt = new Date(data.expiresAt);
  const attempts = data.attempts || 0;

  if (new Date() > expiresAt) {
    await docRef.delete();
    return res.status(400).json({ error: 'OTP code has expired. Please request a new one.' });
  }

  if (attempts >= 5) {
    await docRef.delete();
    return res.status(400).json({ error: 'Too many incorrect attempts. Please request a new code.' });
  }

  // Hash the provided OTP code to compare against Firestore hash
  const hashedEntered = crypto
    .createHash('sha256')
    .update(`${otp.trim()}:${docId}`)
    .digest('hex');

  if (hashedEntered !== data.hashedCode) {
    await docRef.update({ attempts: attempts + 1 });
    return res.status(401).json({ error: 'Invalid OTP code. Please go back and verify.' });
  }

  // All checks passed — update password via Admin SDK
  try {
    const userRecord = await admin.auth().getUserByEmail(cleanEmail);
    await admin.auth().updateUser(userRecord.uid, { password: newPassword });
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      return res.status(404).json({ error: 'No account found with this email.' });
    }
    console.error('updateUser error:', e);
    return res.status(500).json({ error: 'Failed to update password. Please try again.' });
  }

  // Clean up OTP doc upon successful password update
  try { await docRef.delete(); } catch (_) {}

  return res.status(200).json({ success: true });
};
