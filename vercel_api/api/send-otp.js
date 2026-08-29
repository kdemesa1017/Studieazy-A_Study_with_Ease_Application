const admin = require('firebase-admin');
const crypto = require('crypto');
const https = require('https');

// Initialize Firebase Admin once
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

const EMAILJS_SERVICE_ID = 'service_i3ek35b';
const EMAILJS_TEMPLATE_ID = 'template_va0wg76';
const EMAILJS_PUBLIC_KEY = '7-547Pitrocp66hMl';

function getFpDocId(email) {
  const clean = email.trim().toLowerCase();
  return 'fp_' + crypto.createHash('sha256').update(clean).digest('hex');
}

function generateOtpCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function sendEmailViaEmailJs(toEmail, otpCode) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      service_id: EMAILJS_SERVICE_ID,
      template_id: EMAILJS_TEMPLATE_ID,
      user_id: EMAILJS_PUBLIC_KEY,
      template_params: { to_email: toEmail, otp_code: otpCode },
    });

    const options = {
      hostname: 'api.emailjs.com',
      port: 443,
      path: '/api/v1.0/email/send',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve();
        } else {
          reject(new Error(`EmailJS failed with status ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.write(postData);
    req.end();
  });
}

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { email } = req.body || {};

  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'Valid email is required.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const docId = getFpDocId(cleanEmail);
  const otpCode = generateOtpCode();

  // Hash code before saving
  const hashedCode = crypto
    .createHash('sha256')
    .update(`${otpCode}:${docId}`)
    .digest('hex');

  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins TTL

  // 1. Check rate limit (60s cooldown per email) & save hashed OTP to Firestore using Admin SDK
  try {
    const docRef = db.collection('otp_codes').doc(docId);
    const existingDoc = await docRef.get();

    if (existingDoc.exists) {
      const data = existingDoc.data();
      if (data.lastSentAt) {
        const elapsedMs = Date.now() - new Date(data.lastSentAt).getTime();
        const cooldownMs = 60 * 1000; // 60 seconds
        if (elapsedMs < cooldownMs) {
          const secondsLeft = Math.ceil((cooldownMs - elapsedMs) / 1000);
          return res.status(429).json({
            error: `Please wait ${secondsLeft} second${secondsLeft > 1 ? 's' : ''} before requesting another code.`,
          });
        }
      }
    }

    await docRef.set({
      hashedCode: hashedCode,
      email: cleanEmail,
      expiresAt: expiresAt.toISOString(),
      lastSentAt: new Date().toISOString(),
      attempts: 0,
      createdAt: new Date().toISOString(),
    });
  } catch (e) {
    console.error('Firestore Admin set error:', e);
    return res.status(500).json({ error: 'Failed to generate verification code. Please try again.' });
  }

  // 2. Send email with plain OTP code via EmailJS
  try {
    await sendEmailViaEmailJs(cleanEmail, otpCode);
  } catch (e) {
    console.error('EmailJS send error:', e);
    return res.status(500).json({ error: 'Failed to send verification email. Please check your email address.' });
  }

  return res.status(200).json({ success: true, message: 'OTP sent successfully.' });
};
