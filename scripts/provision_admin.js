// File: scripts/provision_admin.js
// Script to dynamically provision the first administrator user in a new Firebase/GCP environment
// Usage: node provision_admin.js <email> <fullName> [orgUnitId]
//
// Setup dependencies:
// npm install firebase-admin
//
// Environment configuration:
// For Remote GCP: Set GOOGLE_APPLICATION_CREDENTIALS to service account json file path.
// For Local Emulator: Set FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099" and FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"

const admin = require('firebase-admin');

// Ensure command-line arguments are provided
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("Usage: node provision_admin.js <email> <fullName> [orgUnitId]");
  process.exit(1);
}

const email = args[0].trim().toLowerCase();
const fullName = args[1].trim();
// Default to the predefined IT DQS team ID if none is supplied
const orgUnitId = args[2] ? args[2].trim() : 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d';

// Initialize Firebase Admin SDK
// Uses GOOGLE_APPLICATION_CREDENTIALS env var automatically, or defaults to application credentials.
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();
const auth = admin.auth();

async function provisionAdmin() {
  console.log(`Attempting to provision administrator: ${fullName} (${email})`);

  try {
    // 1. Create or retrieve user in Firebase Authentication
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
      console.log(`User already exists in Firebase Authentication (UID: ${userRecord.uid})`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Generate a cryptographically secure-ish random temp password
        const tempPassword = Math.random().toString(36).slice(-10) + 'A1!' + Math.random().toString(36).slice(-4).toUpperCase();
        userRecord = await auth.createUser({
          email: email,
          emailVerified: true,
          displayName: fullName,
          password: tempPassword,
          disabled: false
        });
        console.log(`Created new Firebase Auth user.`);
        console.log(`Temporary password (please change immediately): ${tempPassword}`);
      } else {
        throw error;
      }
    }

    // 2. Create or update user profile document in Firestore
    const userDocRef = db.collection('users').doc(email);
    
    // We construct the user model following the UserModel schema in Flutter
    const userData = {
      id: userRecord.uid,
      fullName: fullName,
      email: email,
      title: 'System Administrator',
      status: 'Active',
      role: 'Administrator',
      orgUnitId: orgUnitId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await userDocRef.set(userData, { merge: true });
    console.log(`Successfully provisioned Firestore profile document at users/${email} with role: Administrator`);

    console.log("Provisioning complete!");
    process.exit(0);
  } catch (err) {
    console.error("Error provisioning admin user:", err);
    process.exit(2);
  }
}

provisionAdmin();
