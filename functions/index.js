const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();

const MAILGUN_API_KEY = process.env.MAILGUN_API_KEY || (functions.config().mailgun ? functions.config().mailgun.key : null);
const MAILGUN_DOMAIN = process.env.MAILGUN_DOMAIN || (functions.config().mailgun ? functions.config().mailgun.domain : 'sandbox6ae2ae47276c4569aaf5e46d2046f203.mailgun.org');
const MAILGUN_BASE_URL = process.env.MAILGUN_BASE_URL || 'https://api.mailgun.net';
const FROM_EMAIL = `Cappla App <postmaster@${MAILGUN_DOMAIN}>`;

// Helper to send email using Mailgun API
async function sendMail(to, subject, html) {
  const url = `${MAILGUN_BASE_URL}/v3/${MAILGUN_DOMAIN}/messages`;
  const auth = Buffer.from(`api:${MAILGUN_API_KEY}`).toString('base64');
  
  const body = new URLSearchParams();
  body.append('from', FROM_EMAIL);
  body.append('to', to);
  body.append('subject', subject);
  body.append('html', html);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: body.toString()
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Mailgun error: ${response.status} - ${errorText}`);
  }

  return response.json();
}

// 1. Triggered when a new document is written to /passwordResetRequests/{email}
exports.onRequestResetCode = functions.region('europe-west3').firestore
  .document('passwordResetRequests/{email}')
  .onCreate(async (snap, context) => {
    const email = context.params.email.toLowerCase().trim();
    const data = snap.data();
    
    try {
      // Check if user exists in users collection
      const userSnap = await db.collection('users').doc(email).get();
      if (!userSnap.exists) {
        await snap.ref.update({
          status: 'error',
          error: 'User not found in system.'
        });
        return;
      }

      // Generate a cryptographically secure 6-digit code
      const code = crypto.randomInt(100000, 1000000).toString();
      const hashedCode = crypto.createHash('sha256').update(code).digest('hex');
      const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 15 * 60 * 1000)); // 15 minutes

      // Store in /passwordResets/{email}
      await db.collection('passwordResets').doc(email).set({
        email: email,
        code: hashedCode,
        expiresAt: expiresAt
      });

      // Send the email
      const html = `
        <div style="font-family: sans-serif; padding: 20px;">
          <p>Hello,</p>
          <p>We received a request to reset your password. Use the following verification code to proceed:</p>
          <h2 style="font-size: 24px; letter-spacing: 2px; color: #006699;">${code}</h2>
          <p>This code will expire in 15 minutes.</p>
          <p>If you did not request a password reset, please ignore this email.</p>
          <br>
          <p>Best regards,<br>The Cappla Team</p>
        </div>
      `;
      await sendMail(email, 'Password Reset Verification Code', html);

      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
    } catch (err) {
      console.error('Error in onRequestResetCode:', err);
      await snap.ref.update({
        status: 'error',
        error: err.message
      });
    }
  });

// 2. Triggered when a new document is written to /passwordResetVerifications/{email}
exports.onCheckResetCode = functions.region('europe-west3').firestore
  .document('passwordResetVerifications/{email}')
  .onCreate(async (snap, context) => {
    const email = context.params.email.toLowerCase().trim();
    const data = snap.data();
    
    try {
      const code = data.code;
      if (!code) {
        await snap.ref.update({
          status: 'error',
          error: 'Code is required.'
        });
        return;
      }

      // Check the verification code
      const resetSnap = await db.collection('passwordResets').doc(email).get();
      if (!resetSnap.exists) {
        await snap.ref.update({
          status: 'error',
          error: 'No active verification code request found.'
        });
        return;
      }

      const resetData = resetSnap.data();
      const expiresAt = resetData.expiresAt.toDate();
      const hashedEnteredCode = crypto.createHash('sha256').update(code.trim()).digest('hex');

      if (new Date() > expiresAt) {
        await snap.ref.update({
          status: 'error',
          error: 'Verification code has expired.'
        });
        return;
      }

      if (hashedEnteredCode !== resetData.code) {
        await snap.ref.update({
          status: 'error',
          error: 'Incorrect verification code.'
        });
        return;
      }

      await snap.ref.update({
        status: 'verified'
      });
      
    } catch (err) {
      console.error('Error in onCheckResetCode:', err);
      await snap.ref.update({
        status: 'error',
        error: err.message
      });
    }
  });

// 3. Triggered when a new document is written to /passwordResetSubmissions/{email}
exports.onVerifyResetCode = functions.region('europe-west3').firestore
  .document('passwordResetSubmissions/{email}')
  .onCreate(async (snap, context) => {
    const email = context.params.email.toLowerCase().trim();
    const data = snap.data();
    
    try {
      const code = data.code;
      const newPassword = data.newPassword;

      if (!code || !newPassword) {
        await snap.ref.update({
          status: 'error',
          error: 'Invalid request: code and newPassword are required.'
        });
        return;
      }

      // Check the verification code
      const resetSnap = await db.collection('passwordResets').doc(email).get();
      if (!resetSnap.exists) {
        await snap.ref.update({
          status: 'error',
          error: 'No active verification code request found.'
        });
        return;
      }

      const resetData = resetSnap.data();
      const expiresAt = resetData.expiresAt.toDate();
      const hashedEnteredCode = crypto.createHash('sha256').update(code.trim()).digest('hex');

      if (new Date() > expiresAt) {
        await snap.ref.update({
          status: 'error',
          error: 'Verification code has expired.'
        });
        return;
      }

      if (hashedEnteredCode !== resetData.code) {
        await snap.ref.update({
          status: 'error',
          error: 'Incorrect verification code.'
        });
        return;
      }

      // Get user in Auth
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
      } catch (err) {
        await snap.ref.update({
          status: 'error',
          error: 'Authentication record not found: ' + err.message
        });
        return;
      }

      // Update password in Auth
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword
      });

      // Cleanup
      await db.collection('passwordResets').doc(email).delete();
      
      await snap.ref.update({
        status: 'success',
        completedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
    } catch (err) {
      console.error('Error in onVerifyResetCode:', err);
      await snap.ref.update({
        status: 'error',
        error: err.message
      });
    }
  });

// 4. Triggered when a new document is written to /activationRequests/{email}
exports.onSendActivationEmail = functions.region('europe-west3').firestore
  .document('activationRequests/{email}')
  .onCreate(async (snap, context) => {
    const email = context.params.email.toLowerCase().trim();
    const data = snap.data();
    
    try {
      const baseUrl = data.baseUrl;
      if (!baseUrl) {
        console.error('No baseUrl provided in activation request.');
        return;
      }

      // Link to the reset password page of the correct environment pre-populated with the email
      const resetLink = `${baseUrl}/#/reset-password?email=${encodeURIComponent(email)}`;

      const html = `
        <div style="font-family: sans-serif; padding: 20px;">
          <p>Hello,</p>
          <p>Welcome to Cappla! An account has been created for you in the planning portal.</p>
          <p>To set your password and activate your account, please click the link below:</p>
          <p><a href="${resetLink}" style="display: inline-block; padding: 10px 20px; color: #fff; background-color: #007799; text-decoration: none; border-radius: 4px;">Activate Account</a></p>
          <p>Alternatively, copy and paste this link into your browser:</p>
          <p><a href="${resetLink}">${resetLink}</a></p>
          <br>
          <p>Best regards,<br>The Cappla Team</p>
        </div>
      `;
      
      await sendMail(email, 'Activate Your Cappla Account', html);
      console.log(`Successfully sent activation email to ${email}`);

      // Delete the request document after successful sending
      await snap.ref.delete();
      
    } catch (err) {
      console.error('Error in onSendActivationEmail:', err);
    }
  });
