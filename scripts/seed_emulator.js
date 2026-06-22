// File: scripts/seed_emulator.js
// Script to seed the local Firebase emulator environment with initial data
//
// Usage:
// export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
// export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
// node seed_emulator.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK targeting the emulator
admin.initializeApp({
  projectId: process.env.GCP_PROJECT || 'demo-cappla-app'
});

const db = admin.firestore();
const auth = admin.auth();

const USERS = [
  {
    email: 'malikjannico.press@vetter-pharma.com',
    password: '@Ahpgkah9ST#Jxmp',
    fullName: 'Malik Jannico Press',
    role: 'Administrator',
    title: 'Administrator',
    orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'
  },
  {
    email: 'mateo.kevric@vetter-pharma.com',
    password: '@Ahpgkah9ST#Jxmp',
    fullName: 'Mateo Kevric',
    role: 'User',
    title: 'Employee',
    orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'
  },
  {
    email: 'sandro.perez.veiga@vetter-pharma.com',
    password: '@Ahpgkah9ST#Jxmp',
    fullName: 'Sandro Perez Veiga',
    role: 'User',
    title: 'Team Lead',
    orgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'
  },
  {
    email: 'sven.reisenhauer@vetter-pharma.com',
    password: '@Ahpgkah9ST#Jxmp',
    fullName: 'Sven Reisenhauer',
    role: 'User',
    title: 'Employee',
    orgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'
  }
];

const ORG_UNITS = [
  {
    id: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    name: 'IT Core Solutions',
    abbreviation: 'IT CS',
    headOfEmail: 'malikjannico.press@vetter-pharma.com',
    type: 'department',
    status: 'Active',
    parentId: null,
    childIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d']
  },
  {
    id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    name: 'IT Document & Quality Solutions',
    abbreviation: 'IT DQS',
    headOfEmail: 'malikjannico.press@vetter-pharma.com',
    type: 'team',
    status: 'Active',
    parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    childIds: []
  },
  {
    id: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
    name: 'IT Manufacturing & Lab Solutions',
    abbreviation: 'IT MLS',
    headOfEmail: 'sandro.perez.veiga@vetter-pharma.com',
    type: 'team',
    status: 'Active',
    parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    childIds: []
  }
];

const CATEGORIES = [
  {
    id: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
    name: 'Veeva',
    ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 1
  },
  {
    id: '9c5fa00e-26a9-4672-97cf-69bd59bb9304',
    name: 'Docusign',
    ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 2
  },
  {
    id: '08a1faef-75a7-4e76-8f24-63bd59e13028',
    name: 'TrackWise',
    ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 3
  },
  {
    id: 'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
    name: 'MES',
    ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 1
  },
  {
    id: 'be6c4643-7a3c-4467-93e1-0fa138e6f1f6',
    name: 'LIMS',
    ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 2
  }
];

const ACTIVITY_GROUPS = [
  {
    id: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
    name: 'Außerbetrieblich',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 1
  },
  {
    id: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
    name: 'Linientätigkeiten',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 2
  },
  {
    id: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
    name: 'Releasemanagement',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 3
  },
  {
    id: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
    name: 'Projektportfolio',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 4
  },
  {
    id: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
    name: 'Strategie',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 5
  },
  {
    id: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
    name: 'Sonstiges',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 6
  }
];

const ACTIVITIES = [
  {
    id: 'de6c4643-7a3c-4467-93e1-0fa138e6f1f4',
    name: 'Feiertage',
    activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
    type: 'Unlimited',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 1,
    assignedUserEmails: ['malikjannico.press@vetter-pharma.com', 'mateo.kevric@vetter-pharma.com', 'sandro.perez.veiga@vetter-pharma.com', 'sven.reisenhauer@vetter-pharma.com']
  },
  {
    id: 'ca872589-9a74-4bfa-948f-622be8fa6002',
    name: 'Urlaub',
    activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
    type: 'Unlimited',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 2,
    assignedUserEmails: ['malikjannico.press@vetter-pharma.com', 'mateo.kevric@vetter-pharma.com', 'sandro.perez.veiga@vetter-pharma.com', 'sven.reisenhauer@vetter-pharma.com']
  },
  {
    id: '26c91e3e-48a5-48fa-89cf-72b9aef46003',
    name: 'Studium',
    activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
    type: 'Unlimited',
    ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    sharedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    appliedOrgUnitIds: ['8e6c4643-7a3c-4467-93e1-0fa138e6f1f3', 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d', 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
    statusMap: {
      '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'
    },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 3,
    assignedUserEmails: ['malikjannico.press@vetter-pharma.com', 'mateo.kevric@vetter-pharma.com', 'sandro.perez.veiga@vetter-pharma.com', 'sven.reisenhauer@vetter-pharma.com']
  },
  {
    id: '48fe912a-00cd-44b2-b0cf-53e9aef86004',
    name: 'Linientätigkeit 1',
    activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
    type: 'Unlimited',
    ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 1,
    assignedUserEmails: ['malikjannico.press@vetter-pharma.com', 'mateo.kevric@vetter-pharma.com']
  },
  {
    id: '82fae1ab-590f-48fa-a10c-12bc9aef7005',
    name: 'Linientätigkeit 2',
    activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
    categoryId: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
    type: 'Unlimited',
    ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    sharedOrgUnitIds: [],
    appliedOrgUnitIds: ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
    statusMap: { 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active' },
    createdBy: 'system',
    createdAt: new Date().toISOString(),
    lastModifiedBy: 'system',
    lastModifiedAt: new Date().toISOString(),
    order: 2,
    assignedUserEmails: ['malikjannico.press@vetter-pharma.com', 'mateo.kevric@vetter-pharma.com']
  }
];

async function seed() {
  console.log("Starting emulator database seeding...");

  // 1. Seed Authentication accounts
  for (const u of USERS) {
    try {
      await auth.createUser({
        uid: u.email.trim().toLowerCase().hashCode ? u.email.trim().toLowerCase().hashCode().toString() : undefined,
        email: u.email,
        displayName: u.fullName,
        password: u.password,
        emailVerified: true
      });
      console.log(`Created Auth user: ${u.email}`);
    } catch (e) {
      if (e.code === 'auth/email-already-exists' || e.code === 'auth/uid-already-exists') {
        console.log(`Auth user already exists: ${u.email}`);
      } else {
        console.error(`Error creating Auth user ${u.email}:`, e);
      }
    }
  }

  // 2. Seed User profiles in Firestore
  for (const u of USERS) {
    const userDocRef = db.collection('users').doc(u.email.trim().toLowerCase());
    await userDocRef.set({
      id: u.email.trim().toLowerCase().split('@')[0], // matching hash or key ID
      fullName: u.fullName,
      email: u.email.trim().toLowerCase(),
      title: u.title,
      status: 'Active',
      role: u.role,
      orgUnitId: u.orgUnitId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Seed standard capacity row
    const capId = `standard_${u.email.trim().toLowerCase()}`;
    await db.collection('userCapacities').doc(capId).set({
      id: capId,
      userEmail: u.email.trim().toLowerCase(),
      type: 'Standard',
      monday: 8.0,
      tuesday: 8.0,
      wednesday: 8.0,
      thursday: 8.0,
      friday: 8.0,
      saturday: 0.0,
      sunday: 0.0
    }, { merge: true });
  }
  console.log("Seeded user profiles and capacities.");

  // 3. Seed Org Units
  for (const o of ORG_UNITS) {
    await db.collection('orgUnits').doc(o.id).set({
      id: o.id,
      name: o.name,
      abbreviation: o.abbreviation,
      headOfEmail: o.headOfEmail,
      type: o.type,
      status: o.status,
      parentId: o.parentId,
      childIds: o.childIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }
  console.log("Seeded org units.");

  // 4. Seed Categories
  for (const c of CATEGORIES) {
    await db.collection('categories').doc(c.id).set(c, { merge: true });
  }
  console.log("Seeded categories.");

  // 5. Seed Activity Groups
  for (const g of ACTIVITY_GROUPS) {
    await db.collection('activityGroups').doc(g.id).set(g, { merge: true });
  }
  console.log("Seeded activity groups.");

  // 6. Seed Activities
  for (const a of ACTIVITIES) {
    await db.collection('activities').doc(a.id).set(a, { merge: true });
  }
  console.log("Seeded activities.");

  console.log("Seeding completed successfully!");
  process.exit(0);
}

seed().catch(err => {
  console.error("Seeding error:", err);
  process.exit(1);
});
