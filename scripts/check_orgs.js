// scripts/check_orgs.js
const admin = require('firebase-admin');

// Initialize Firebase Admin for remote GCP project
admin.initializeApp({
  projectId: 'cappla-app'
});

const db = admin.firestore();

async function run() {
  try {
    console.log("Checking remote Firestore collections...");
    
    const usersSnap = await db.collection('users').get();
    console.log(`\n--- USERS (${usersSnap.size}) ---`);
    usersSnap.forEach(doc => {
      const data = doc.data();
      console.log(`Email: ${doc.id}, Name: ${data.fullName}, OrgUnitId: ${data.orgUnitId}, Role: ${data.role}`);
    });

    const orgUnitsSnap = await db.collection('orgUnits').get();
    console.log(`\n--- ORG UNITS (${orgUnitsSnap.size}) ---`);
    orgUnitsSnap.forEach(doc => {
      const data = doc.data();
      console.log(`ID: ${doc.id}, Name: ${data.name}, Status: ${data.status}`);
    });

    process.exit(0);
  } catch (error) {
    console.error("Error checking Firestore:", error);
    process.exit(1);
  }
}

run();
