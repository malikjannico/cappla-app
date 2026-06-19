// scripts/cleanup_remote.js
const admin = require('firebase-admin');

// Initialize Firebase Admin for remote GCP project
admin.initializeApp({
  projectId: 'cappla-app'
});

const db = admin.firestore();
const auth = admin.auth();

const SEEDED_USER_EMAILS = [
  'mateo.kevric@vetter-pharma.com',
  'sandro.perez.veiga@vetter-pharma.com',
  'sven.reisenhauer@vetter-pharma.com'
];

const SEEDED_ORG_UNIT_IDS = [
  '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
  'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
  'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'
];

const SEEDED_CATEGORY_IDS = [
  '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
  '9c5fa00e-26a9-4672-97cf-69bd59bb9304',
  '08a1faef-75a7-4e76-8f24-63bd59e13028',
  'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
  'be6c4643-7a3c-4467-93e1-0fa138e6f1f6'
];

const SEEDED_ACTIVITY_GROUP_IDS = [
  'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
  'a5f1a547-4927-4a7b-a010-3375c3db7383',
  'd8bf59cf-2b83-4a75-b463-b883015f5e55',
  '1a329d72-9746-4cb4-9be1-081cb8d956f6',
  '8d3e913a-a16f-4421-9876-0bfdc92b5120',
  '57bcde82-f703-4c91-b68e-9d24cbfa6001'
];

const SEEDED_ACTIVITY_IDS = [
  'de6c4643-7a3c-4467-93e1-0fa138e6f1f4',
  'ca872589-9a74-4bfa-948f-622be8fa6002',
  '26c91e3e-48a5-48fa-89cf-72b9aef46003',
  '48fe912a-00cd-44b2-b0cf-53e9aef86004',
  '82fae1ab-590f-48fa-a10c-12bc9aef7005'
];

async function cleanup() {
  console.log("Starting remote database cleanup...");

  // 1. Delete seeded Auth accounts & Firestore profiles
  for (const email of SEEDED_USER_EMAILS) {
    try {
      const userRecord = await auth.getUserByEmail(email);
      await auth.deleteUser(userRecord.uid);
      console.log(`Deleted Auth user: ${email}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        console.log(`Auth user not found (already deleted): ${email}`);
      } else {
        console.error(`Error deleting Auth user ${email}:`, e);
      }
    }

    try {
      await db.collection('users').doc(email).delete();
      console.log(`Deleted Firestore user profile: ${email}`);
    } catch (e) {
      console.error(`Error deleting Firestore profile for ${email}:`, e);
    }

    try {
      const capId = `standard_${email}`;
      await db.collection('userCapacities').doc(capId).delete();
      console.log(`Deleted user capacity: ${capId}`);
    } catch (e) {
      console.error(`Error deleting user capacity for ${email}:`, e);
    }
  }

  // 2. Delete seeded Org Units
  for (const id of SEEDED_ORG_UNIT_IDS) {
    try {
      await db.collection('orgUnits').doc(id).delete();
      console.log(`Deleted org unit document: ${id}`);
    } catch (e) {
      console.error(`Error deleting org unit ${id}:`, e);
    }
  }

  // 3. Delete seeded Categories
  for (const id of SEEDED_CATEGORY_IDS) {
    try {
      await db.collection('categories').doc(id).delete();
      console.log(`Deleted category document: ${id}`);
    } catch (e) {
      console.error(`Error deleting category ${id}:`, e);
    }
  }

  // 4. Delete seeded Activity Groups
  for (const id of SEEDED_ACTIVITY_GROUP_IDS) {
    try {
      await db.collection('activityGroups').doc(id).delete();
      console.log(`Deleted activity group document: ${id}`);
    } catch (e) {
      console.error(`Error deleting activity group ${id}:`, e);
    }
  }

  // 5. Delete seeded Activities
  for (const id of SEEDED_ACTIVITY_IDS) {
    try {
      await db.collection('activities').doc(id).delete();
      console.log(`Deleted activity document: ${id}`);
    } catch (e) {
      console.error(`Error deleting activity ${id}:`, e);
    }
  }

  console.log("Remote database cleanup completed successfully!");
  process.exit(0);
}

cleanup().catch(err => {
  console.error("Cleanup error:", err);
  process.exit(1);
});
