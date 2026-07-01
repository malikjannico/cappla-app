import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_document_reference.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'package:cappla/firebase_options.dart';

// =========================================================================
// MOCK / FAKE CLASSES FOR FIREBASE (Modern, type-safe wrappers)
// =========================================================================

class MockFirebaseAuthWithRegistry extends MockFirebaseAuth {
  final Map<String, String> _userCredentials = {}; // email -> password
  final List<String> sentPasswordResets = [];

  MockFirebaseAuthWithRegistry() : super(signedIn: false);

  void registerUser(String email, String password) {
    _userCredentials[email.trim().toLowerCase()] = password;
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_userCredentials.containsKey(normalizedEmail) &&
        _userCredentials[normalizedEmail] == password) {
      final id = normalizedEmail.hashCode.toString();
      mockUser = MockUser(
        uid: id,
        email: normalizedEmail,
        displayName: normalizedEmail.split('@').first,
      );
      return super.signInWithEmailAndPassword(email: email, password: password);
    } else {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The email address or password is incorrect.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    sentPasswordResets.add(email.trim().toLowerCase());
    return super.sendPasswordResetEmail(email: email, actionCodeSettings: actionCodeSettings);
  }
}

class MockFirebaseFirestoreWithHelpers extends FakeFirebaseFirestore {
  void setData(String collection, String docId, Map<String, dynamic> data) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;

    if (collection == 'orgUnits') {
      final parentId = data['parentId'] as String?;
      if (parentId != null) {
        if (parentId == normalizedDocId) {
          throw Exception('Cycle detected: Cannot set parent to itself.');
        }
        String? current = parentId;
        while (current != null) {
          if (current == normalizedDocId) {
            throw Exception('Cycle detected: Circular hierarchy not allowed.');
          }
          final parentData = getData('orgUnits', current);
          if (parentData == null) break;
          current = parentData['parentId'] as String?;
        }
      }
    }

    final docRef = this.collection(collection).doc(normalizedDocId) as MockDocumentReference;
    docRef.docsData[docRef.path] = data;
    saveDocument(docRef.path);
    docRef.set(Map<String, dynamic>.from(data));
  }

  Map<String, dynamic>? getData(String collection, String docId) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;
    final path = '$collection/$normalizedDocId';
    final docRef = doc(path) as MockDocumentReference;
    final rawData = docRef.docsData[docRef.path];
    if (rawData == null) return null;
    return Map<String, dynamic>.from(rawData);
  }

  Map<String, Map<String, Map<String, dynamic>>> get collections {
    final docRef = doc('dummy/dummy') as MockDocumentReference;
    final docsMap = docRef.docsData;
    final Map<String, Map<String, Map<String, dynamic>>> result = {
      'users': {},
      'orgUnits': {},
      'categories': {},
      'activityGroups': {},
      'activities': {},
      'userCapacities': {},
    };
    for (final entry in docsMap.entries) {
      final path = entry.key;
      final parts = path.split('/');
      if (parts.length == 2) {
        final col = parts[0];
        final id = parts[1];
        final val = entry.value;
        if (val is Map) {
          result.putIfAbsent(col, () => {})[id] = Map<String, dynamic>.from(val);
        }
      }
    }
    return result;
  }

  void deleteData(String collection, String docId) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;
    final docRef = this.collection(collection).doc(normalizedDocId) as MockDocumentReference;
    docRef.docsData.remove(docRef.path);
    removeSavedDocument(docRef.path);
    docRef.delete();
  }

  void clear() {
    clearPersistence();
  }
}

class E2ETestHarness {
  final MockFirebaseAuthWithRegistry mockAuth = MockFirebaseAuthWithRegistry();
  final MockFirebaseFirestoreWithHelpers mockFirestore = MockFirebaseFirestoreWithHelpers();
  late final ProviderContainer container;

  E2ETestHarness() {
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.local,
            firebaseOptions: DefaultFirebaseOptions.local,
            useEmulator: false,
            isTesting: true,
          ),
        ),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        firestoreProvider.overrideWithValue(mockFirestore),
      ],
    );
  }

  /// Reset Auth and DB to clear state
  void clearAll() {
    mockFirestore.clear();
    mockAuth.signOut();
    container.dispose();
  }

  /// Initialize database with seeded administrator: Malik Jannico Press
  void seedAdminUser() {
    final adminUser = UserModel(
      id: '00000000-0000-0000-0000-000000000000',
      fullName: 'Malik Jannico Press',
      email: 'MalikJannico.Press@vetter-pharma.com',
      title: 'Administrator',
      status: 'Active',
      role: 'Administrator',
      orgUnitId: null,
    );
    seedUser(adminUser, 'AdminPassword123!');
  }

  /// Seed an arbitrary user
  void seedUser(UserModel user, String password) {
    // Save credentials in mock auth
    mockAuth.registerUser(user.email, password);
    // Save profile in mock firestore
    final lowerEmail = user.email.trim().toLowerCase();
    mockFirestore.setData('users', lowerEmail, user.toMap());

    // Seed the default standard capacity row for this user
    final capacityDocId = 'standard_$lowerEmail';
    mockFirestore.setData('userCapacities', capacityDocId, {
      'id': capacityDocId,
      'userEmail': lowerEmail,
      'type': 'Standard',
      'monday': 8.0,
      'tuesday': 8.0,
      'wednesday': 8.0,
      'thursday': 8.0,
      'friday': 8.0,
      'saturday': 0.0,
      'sunday': 0.0,
    });
  }

  /// Seed an arbitrary organization unit
  void seedOrgUnit(OrgUnitModel orgUnit) {
    mockFirestore.setData('orgUnits', orgUnit.id, orgUnit.toMap());

    // Maintain bidirectional parent-child association
    if (orgUnit.parentId != null) {
      final parentData = mockFirestore.getData('orgUnits', orgUnit.parentId!);
      if (parentData != null) {
        final parent = OrgUnitModel.fromMap(parentData);
        if (!parent.childIds.contains(orgUnit.id)) {
          final updatedChildren = List<String>.from(parent.childIds)
            ..add(orgUnit.id);
          final updatedParent = OrgUnitModel(
            id: parent.id,
            name: parent.name,
            abbreviation: parent.abbreviation,
            headOfEmail: parent.headOfEmail,
            type: parent.type,
            parentId: parent.parentId,
            childIds: updatedChildren,
            status: parent.status,
            createdBy: parent.createdBy,
            createdAt: parent.createdAt,
            lastModifiedBy: parent.lastModifiedBy,
            lastModifiedAt: parent.lastModifiedAt,
          );
          mockFirestore.setData('orgUnits', parent.id, updatedParent.toMap());
        }
      }
    }
  }

  /// Remove user from database
  void removeUser(String email) {
    mockFirestore.deleteData('users', email.trim().toLowerCase());
  }

  /// Remove organization unit from database and cleanup parent associations
  void removeOrgUnit(String id) {
    final data = mockFirestore.getData('orgUnits', id);
    if (data == null) return;

    final org = OrgUnitModel.fromMap(data);

    // Clear parent association in child units
    for (var childId in org.childIds) {
      final childData = mockFirestore.getData('orgUnits', childId);
      if (childData != null) {
        final child = OrgUnitModel.fromMap(childData);
        final updatedChild = OrgUnitModel(
          id: child.id,
          name: child.name,
          abbreviation: child.abbreviation,
          headOfEmail: child.headOfEmail,
          type: child.type,
          parentId: null, // Clear reference
          childIds: child.childIds,
          status: child.status,
          createdBy: child.createdBy,
          createdAt: child.createdAt,
          lastModifiedBy: child.lastModifiedBy,
          lastModifiedAt: child.lastModifiedAt,
        );
        mockFirestore.setData('orgUnits', child.id, updatedChild.toMap());
      }
    }

    // Clear child association in parent unit
    if (org.parentId != null) {
      final parentData = mockFirestore.getData('orgUnits', org.parentId!);
      if (parentData != null) {
        final parent = OrgUnitModel.fromMap(parentData);
        final updatedChildren = List<String>.from(parent.childIds)..remove(id);
        final updatedParent = OrgUnitModel(
          id: parent.id,
          name: parent.name,
          abbreviation: parent.abbreviation,
          headOfEmail: parent.headOfEmail,
          type: parent.type,
          parentId: parent.parentId,
          childIds: updatedChildren,
          status: parent.status,
          createdBy: parent.createdBy,
          createdAt: parent.createdAt,
          lastModifiedBy: parent.lastModifiedBy,
          lastModifiedAt: parent.lastModifiedAt,
        );
        mockFirestore.setData('orgUnits', parent.id, updatedParent.toMap());
      }
    }

    mockFirestore.deleteData('orgUnits', id);
  }

  /// Helper to sign in as user and set current state
  Future<void> signIn(String email, String password) async {
    await mockAuth.signInWithEmailAndPassword(email: email, password: password);
    final userData = mockFirestore.getData('users', email);
    if (userData != null) {
      final user = UserModel.fromMap(userData);
      if (user.status == UserStatus.inactive) {
        mockAuth.signOut();
        throw Exception('auth/user-disabled');
      }
    } else {
      throw Exception('auth/user-not-found');
    }
    // Wait for the stream provider to load the user
    await container.read(authStateSyncProvider.future);
  }

  /// Helper to sign out
  Future<void> signOut() async {
    await mockAuth.signOut();
    await container.read(authStateSyncProvider.future);
  }
}

typedef MockFirebaseFirestore = MockFirebaseFirestoreWithHelpers;
