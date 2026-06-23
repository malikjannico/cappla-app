const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const APP_BASE_URL = (process.env.APP_BASE_URL || '').replace(/\/+$/, '');
const LOGO_URL = `${APP_BASE_URL}/favicon.png?v=1.0.1`;

function loadTemplate(templateName, variables) {
  const templatePath = path.join(__dirname, 'templates', `${templateName}.html`);
  let content = fs.readFileSync(templatePath, 'utf8');
  
  const allVars = { logoUrl: LOGO_URL, ...variables };
  
  for (const [key, value] of Object.entries(allVars)) {
    content = content.replaceAll(`{{${key}}}`, value);
  }
  return content;
}

admin.initializeApp();

const db = admin.firestore();

const MAILGUN_API_KEY = process.env.MAILGUN_API_KEY;
const MAILGUN_DOMAIN = process.env.MAILGUN_DOMAIN;
const MAILGUN_BASE_URL = process.env.MAILGUN_BASE_URL;
const FROM_EMAIL = process.env.FROM_EMAIL;

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
      const html = loadTemplate('reset_code', { code: code });
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

      // Send password changed notification email
      try {
        const html = loadTemplate('password_updated', {});
        await sendMail(email, 'Your Cappla Password Has Been Updated', html);
        console.log(`Successfully sent password updated email to ${email}`);
      } catch (mailErr) {
        console.error('Error sending password updated email:', mailErr);
      }
      
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

      const html = loadTemplate('activation', { resetLink: resetLink });
      
      await sendMail(email, 'Activate Your Cappla Account', html);
      console.log(`Successfully sent activation email to ${email}`);

      // Delete the request document after successful sending
      await snap.ref.delete();
      
    } catch (err) {
      console.error('Error in onSendActivationEmail:', err);
    }
  });
