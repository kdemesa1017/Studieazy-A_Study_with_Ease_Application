const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const db = admin.firestore();

/**
 * Cloud Function: resetPasswordWithOtp
 *
 * Called from the Flutter app after the user completes in-app OTP verification.
 * Verifies the OTP from Firestore, then uses Firebase Admin SDK to directly
 * update the user's password — no email link required.
 *
 * Input: { email: string, otp: string, newPassword: string }
 * Returns: { success: true } or throws HttpsError
 */
exports.resetPasswordWithOtp = onCall({ region: "us-central1" }, async (request) => {
  const { email, otp, newPassword } = request.data;

  // --- Validate inputs ---
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "A valid email is required.");
  }
  if (!otp || typeof otp !== "string" || otp.length !== 6) {
    throw new HttpsError("invalid-argument", "A valid 6-digit OTP is required.");
  }
  if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  const cleanEmail = email.trim().toLowerCase();

  // --- Compute Firestore doc ID (same hashing as OtpService in Flutter) ---
  const docId = "fp_" + crypto.createHash("sha256").update(cleanEmail).digest("hex");

  // --- Read OTP doc from Firestore ---
  const docRef = db.collection("otp_codes").doc(docId);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new HttpsError("not-found", "No verification code found. Please request a new one.");
  }

  const data = doc.data();
  const expiresAt = new Date(data.expiresAt);
  const attempts = data.attempts || 0;
  const maxAttempts = 5;

  if (new Date() > expiresAt) {
    throw new HttpsError("deadline-exceeded", "This code has expired. Please request a new one.");
  }

  if (attempts >= maxAttempts) {
    throw new HttpsError("resource-exhausted", "Too many incorrect attempts. Please request a new code.");
  }

  // --- Hash the entered OTP the same way Flutter does ---
  const hashedEntered = crypto
    .createHash("sha256")
    .update(`${otp}:${docId}`)
    .digest("hex");

  if (hashedEntered !== data.hashedCode) {
    await docRef.update({ attempts: attempts + 1 });
    throw new HttpsError("unauthenticated", "Incorrect OTP code. Please try again.");
  }

  // --- OTP is valid — update the user's password via Admin SDK ---
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(cleanEmail);
  } catch (err) {
    throw new HttpsError("not-found", "No account found with this email.");
  }

  try {
    await admin.auth().updateUser(userRecord.uid, { password: newPassword });
  } catch (err) {
    throw new HttpsError("internal", "Failed to update password. Please try again.");
  }

  // --- Clean up OTP doc ---
  try {
    await docRef.delete();
  } catch (_) {}

  return { success: true };
});
