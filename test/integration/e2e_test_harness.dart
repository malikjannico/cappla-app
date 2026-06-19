import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';

// =========================================================================
// MOCK / FAKE CLASSES FOR FIREBASE (Used when package imports are unavailable)
// =========================================================================

/// Mock User matching the Firebase User interface
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;

  MockUser({required this.uid, this.email, this.displayName});
}

/// Mock Firebase Auth to simulate login, logout, and password reset flows
class MockFirebaseAuth {
  MockUser? _currentUser;
  final Map<String, String> _userCredentials = {}; // email -> password
  final List<String> sentPasswordResets = [];
  final _authController = StreamController<MockUser?>.broadcast();

  MockUser? get currentUser => _currentUser;

  Stream<MockUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  void registerUser(String email, String password) {
    _userCredentials[email.trim().toLowerCase()] = password;
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_userCredentials.containsKey(normalizedEmail) &&
        _userCredentials[normalizedEmail] == password) {
      _currentUser = MockUser(
        uid: normalizedEmail.hashCode.toString(),
        email: normalizedEmail,
        displayName: normalizedEmail.split('@').first,
      );
      _authController.add(_currentUser);
    } else {
      throw Exception('auth/invalid-credential');
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _authController.add(null);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    sentPasswordResets.add(email.trim().toLowerCase());
  }
}

/// Simple In-Memory Firestore simulation for E2E testing
class MockFirebaseFirestore {
  final _changeController = StreamController<void>.broadcast();
  Stream<void> get onChange => _changeController.stream;

  final Map<String, Map<String, Map<String, dynamic>>> collections = {
    'users': {},
    'orgUnits': {},
    'categories': {},
    'activityGroups': {},
    'activities': {},
    'userCapacities': {},
  };

  void setData(String collection, String docId, Map<String, dynamic> data) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;
    collections[collection] ??= {};
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
          final parentData = collections['orgUnits']?[current];
          if (parentData == null) break;
          current = parentData['parentId'] as String?;
        }
      }
    }
    collections[collection]![normalizedDocId] = data;
    _changeController.add(null);
  }

  Map<String, dynamic>? getData(String collection, String docId) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;
    return collections[collection]?[normalizedDocId];
  }

  void deleteData(String collection, String docId) {
    final normalizedDocId = collection == 'users'
        ? docId.trim().toLowerCase()
        : docId;
    collections[collection]?.remove(normalizedDocId);
    _changeController.add(null);
  }

  void clear() {
    for (var key in collections.keys) {
      collections[key]!.clear();
    }
    _changeController.add(null);
  }
}

// =========================================================================
// E2E TEST HARNESS CLASS
// =========================================================================

class E2ETestHarness {
  final MockFirebaseAuth mockAuth = MockFirebaseAuth();
  final MockFirebaseFirestore mockFirestore = MockFirebaseFirestore();
  late final ProviderContainer container;

  E2ETestHarness() {
    container = ProviderContainer(
      overrides: [
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
      if (user.status == 'Inactive') {
        mockAuth.signOut();
        throw Exception('auth/user-disabled');
      }
      container.read(currentUserProvider.notifier).state = user;
    } else {
      throw Exception('auth/user-not-found');
    }
  }

  /// Helper to sign out
  Future<void> signOut() async {
    await mockAuth.signOut();
    container.read(currentUserProvider.notifier).state = null;
  }
}
