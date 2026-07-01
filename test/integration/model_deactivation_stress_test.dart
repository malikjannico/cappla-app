// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/services/database/database_service.dart';
import 'package:cappla/services/auth_service.dart';
import 'package:cappla/core/providers/providers.dart';
import 'e2e_test_harness.dart';

// ---------------------------------------------------------
// ADVERSARIAL MOCK AUTHENTICATION SYSTEM
// ---------------------------------------------------------
typedef AdversarialMockUser = MockUser;

class AdversarialMockAuth extends MockFirebaseAuth {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser;

  AdversarialMockAuth() : super(signedIn: false);

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() async* {
    print(
      'DEBUG: authStateChanges subscribed. Current user = ${_currentUser?.email}',
    );
    yield _currentUser;
    yield* _controller.stream;
  }

  void emit(User? user) {
    print('DEBUG: emit called with user = ${user?.email}');
    _currentUser = user;
    _controller.add(user);
  }

  final Map<String, String> credentials = {};
  final List<String> sentPasswordResets = [];

  void registerUser(String email, String password) {
    credentials[email] = password;
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    print('DEBUG: signInWithEmailAndPassword called for $email');
    if (credentials.containsKey(email) && credentials[email] == password) {
      mockUser = MockUser(
        email: email,
        uid: email.hashCode.toString(),
      );
      final cred = await super.signInWithEmailAndPassword(email: email, password: password);
      emit(cred.user);
      return cred;
    } else {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The email address or password is incorrect.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await super.signOut();
    emit(null);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    sentPasswordResets.add(email);
  }
}

void main() {
  group('M7 Phase 2 Adversarial & Stress Testing', () {
    late AdversarialMockAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late ProviderContainer container;
    late AuthService authService;
    late DatabaseService dbService;

    setUp(() {
      mockAuth = AdversarialMockAuth();
      mockFirestore = MockFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      authService = container.read(authServiceProvider);
      dbService = container.read(databaseServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    // =========================================================================
    // SECTION 1: AUTH SERVICE ADVERSARIAL & ROBUSTNESS TESTS
    // =========================================================================
    group('AuthService Adversarial Tests', () {
      test(
        '1.1 userStateChanges stream emits null when unauthenticated initially',
        () async {
          final streamExpectation = expectLater(
            authService.userStateChanges,
            emitsThrough(isNull),
          );
          mockAuth.emit(null);
          await streamExpectation;
        },
      );

      test(
        '1.2 userStateChanges stream emits null when auth user email is null or empty',
        () async {
          // Prepare expectations
          final stream = authService.userStateChanges;

          // Listen to collect events
          final events = <UserModel?>[];
          final subscription = stream.listen(events.add);

          // Emit auth user with null email
          mockAuth.emit(AdversarialMockUser(email: null, uid: 'null-user'));
          await Future.delayed(const Duration(milliseconds: 10));

          // Emit auth user with empty email
          mockAuth.emit(AdversarialMockUser(email: '', uid: 'empty-user'));
          await Future.delayed(const Duration(milliseconds: 10));

          subscription.cancel();

          expect(events, contains(isNull));
          expect(events.every((e) => e == null), isTrue);
        },
      );

      test(
        '1.3 userStateChanges propagates mid-session database updates to user profile reactively',
        () async {
          final email = 'reactive.user@vetter.com';
          final initialUser = UserModel(
            id: email,
            fullName: 'Initial Name',
            email: email,
            title: 'Specialist',
            status: 'Active',
            role: 'User',
          );

          // Seed DB and sign in
          await dbService.saveUser(initialUser);
          mockAuth.emit(
            AdversarialMockUser(email: email, uid: email.hashCode.toString()),
          );

          // Start listening to userStateChanges
          final events = <UserModel?>[];
          final completer = Completer<void>();

          final subscription = authService.userStateChanges.listen((user) {
            events.add(user);
            if (events.length == 2) {
              completer.complete();
            }
          });

          // Wait to capture the initial state
          await Future.delayed(const Duration(milliseconds: 10));

          // Update user role and title mid-session in Firestore
          final updatedUser = UserModel(
            id: email,
            fullName: 'Initial Name',
            email: email,
            title: 'Senior Manager',
            status: 'Active',
            role: 'Administrator',
          );
          await dbService.saveUser(updatedUser);

          // Wait for both emissions to complete
          await completer.future;
          subscription.cancel();

          expect(events.length, equals(2));
          expect(events[0]!.title, equals('Specialist'));
          expect(events[0]!.role, equals('User'));
          expect(events[1]!.title, equals('Senior Manager'));
          expect(events[1]!.role, equals('Administrator'));
        },
      );

      test(
        '1.4 signIn completes successfully on valid credentials & Active status',
        () async {
          final email = 'valid.user@vetter.com';
          final password = 'SafePassword123!';

          final user = UserModel(
            id: email,
            fullName: 'Valid User',
            email: email,
            title: 'Specialist',
            status: 'Active',
            role: 'User',
          );

          mockAuth.registerUser(email, password);
          await dbService.saveUser(user);

          // Sign in should complete normally
          await expectLater(
            authService.signIn(email: email, password: password),
            completes,
          );

          expect(mockAuth.currentUser!.email, equals(email));
        },
      );

      test('1.5 signIn throws exception on invalid credentials', () async {
        final email = 'valid.user@vetter.com';
        final password = 'SafePassword123!';

        mockAuth.registerUser(email, password);

        // Sign in with wrong password
        expect(
          () => authService.signIn(email: email, password: 'WrongPassword'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('auth/invalid-credential'),
            ),
          ),
        );
      });

      test(
        '1.6 signIn signs out and throws if user has no database profile',
        () async {
          final email = 'no.profile@vetter.com';
          final password = 'SafePassword123!';

          mockAuth.registerUser(email, password);
          // Do NOT save user to DB

          await expectLater(
            authService.signIn(email: email, password: password),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('User data not found in database.'),
              ),
            ),
          );

          // Verify user is signed out
          expect(mockAuth.currentUser, isNull);
        },
      );

      test(
        '1.7 signIn signs out and throws if user status is Inactive',
        () async {
          final email = 'inactive.user@vetter.com';
          final password = 'SafePassword123!';

          final inactiveUser = UserModel(
            id: email,
            fullName: 'Inactive User',
            email: email,
            title: 'Analyst',
            status: 'Inactive',
            role: 'User',
          );

          mockAuth.registerUser(email, password);
          await dbService.saveUser(inactiveUser);

          await expectLater(
            authService.signIn(email: email, password: password),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Your account is Inactive. Access denied.'),
              ),
            ),
          );

          // Verify user is signed out
          expect(mockAuth.currentUser, isNull);
        },
      );

      test('1.8 signOut clears mock auth session', () async {
        mockAuth.emit(
          AdversarialMockUser(email: 'test@vetter.com', uid: '123'),
        );
        expect(mockAuth.currentUser, isNotNull);

        await authService.signOut();
        expect(mockAuth.currentUser, isNull);
      });

      test(
        '1.9 sendPasswordResetEmail calls mock auth reset mechanism',
        () async {
          final email = 'reset@vetter.com';
          await authService.sendPasswordResetEmail(email: email);
          expect(mockAuth.sentPasswordResets, contains(email));
        },
      );
    });

    // =========================================================================
    // SECTION 2: HIERARCHY, REFERENCE INTEGRITY & DELETION CORNER CASES
    // =========================================================================
    group('DatabaseService Hierarchy & Reference Integrity Tests', () {
      test(
        '2.1 Saving unit with non-existent parentId throws DatabaseValidationException',
        () async {
          final child = OrgUnitModel(
            id: 'CHILD_DANGLING_PARENT',
            name: 'Child with missing parent',
            abbreviation: 'CDP',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: 'NON_EXISTENT_PARENT',
            childIds: [],
            status: 'Active',
          );

          // Verifying it throws DatabaseValidationException
          await expectLater(
            dbService.saveOrgUnit(child),
            throwsA(
              isA<DatabaseValidationException>().having(
                (e) => e.toString(),
                'message',
                contains('Parent unit does not exist.'),
              ),
            ),
          );
        },
      );

      test(
        '2.2 Saving unit with non-existent childIds throws DatabaseValidationException',
        () async {
          final parent = OrgUnitModel(
            id: 'PARENT_DANGLING_CHILD',
            name: 'Parent with missing children',
            abbreviation: 'PDC',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: null,
            childIds: ['NON_EXISTENT_CHILD_1', 'NON_EXISTENT_CHILD_2'],
            status: 'Active',
          );

          await expectLater(
            dbService.saveOrgUnit(parent),
            throwsA(
              isA<DatabaseValidationException>().having(
                (e) => e.toString(),
                'message',
                contains('Child unit does not exist.'),
              ),
            ),
          );
        },
      );

      test(
        '2.3 Deleting org unit containing dangling relations performs gracefully',
        () async {
          final unit = OrgUnitModel(
            id: 'MIDDLE_DANGLING_RELATIONS',
            name: 'Middle unit with dangling relations',
            abbreviation: 'MDR',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: 'MISSING_PARENT',
            childIds: ['MISSING_CHILD'],
            status: 'Active',
          );

          mockFirestore.setData(
            'orgUnits',
            'MIDDLE_DANGLING_RELATIONS',
            unit.toMap(),
          );

          // Deleting should complete without exceptions, ignoring non-existent parent and child
          await expectLater(
            dbService.deleteOrgUnit('MIDDLE_DANGLING_RELATIONS'),
            completes,
          );
          expect(
            await dbService.getOrgUnit('MIDDLE_DANGLING_RELATIONS'),
            isNull,
          );
        },
      );
    });

    // =========================================================================
    // SECTION 3: PERFORMANCE, LIMITS & RECURSION STRESS TESTS
    // =========================================================================
    group('DatabaseService Stress & Recursion Limit Tests', () {
      test(
        '3.1 50-Level Deep Org Unit Hierarchy and Status Propagation Cascade',
        () async {
          final int depth = 50;
          final List<OrgUnitModel> units = [];

          // Generate 50 units in a chain: U0 -> U1 -> U2 -> ... -> U49
          for (int i = 0; i < depth; i++) {
            units.add(
              OrgUnitModel(
                id: 'U$i',
                name: 'Unit level $i',
                abbreviation: 'U$i',
                headOfEmail: 'head@vetter.com',
                type: i == 0 ? 'md division' : 'department',
                parentId: i == 0 ? null : 'U${i - 1}',
                childIds: i == depth - 1 ? [] : ['U${i + 1}'],
                status: 'Active',
              ),
            );
          }

          // Seed using mockFirestore directly since pre-populated tree has bi-directional references to not-yet-created units
          for (int i = 0; i < depth; i++) {
            mockFirestore.setData('orgUnits', units[i].id, units[i].toMap());
          }

          // Verify all units are active
          for (int i = 0; i < depth; i++) {
            final saved = await dbService.getOrgUnit('U$i');
            expect(saved, isNotNull);
            expect(saved!.status, equals('Active'));
          }

          // Deactivate root unit U0
          final inactiveRoot = units[0].copyWith(status: 'Inactive');
          await dbService.saveOrgUnit(inactiveRoot);

          // Verify the status propagated all 50 levels down to U49 without stack overflow
          for (int i = 0; i < depth; i++) {
            final saved = await dbService.getOrgUnit('U$i');
            expect(
              saved!.status,
              equals('Inactive'),
              reason: 'Unit U$i should have cascaded to Inactive',
            );
          }
        },
      );

      test(
        '3.2 Bulk User Disassociation Performance Test (100 users)',
        () async {
          final orgUnit = OrgUnitModel(
            id: 'BULK_DISASSOCIATE_UNIT',
            name: 'Bulk Disassociate Unit',
            abbreviation: 'BDU',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: null,
            childIds: [],
            status: 'Active',
          );

          await dbService.saveOrgUnit(orgUnit);

          // Seed 100 users assigned to this org unit
          final List<UserModel> users = [];
          for (int i = 0; i < 100; i++) {
            final email = 'bulk.user.$i@vetter.com';
            final user = UserModel(
              id: email,
              fullName: 'Bulk User $i',
              email: email,
              title: 'Specialist',
              status: 'Active',
              role: 'User',
              orgUnitId: 'BULK_DISASSOCIATE_UNIT',
            );
            users.add(user);
            await dbService.saveUser(user);
          }

          // Verify they are all assigned
          final dbUsersBefore = await dbService.getAllUsers();
          final assignedBefore = dbUsersBefore
              .where((u) => u.orgUnitId == 'BULK_DISASSOCIATE_UNIT')
              .length;
          expect(assignedBefore, equals(100));

          // Delete the unit
          await dbService.deleteOrgUnit('BULK_DISASSOCIATE_UNIT');

          // Verify that the unit is deleted
          expect(await dbService.getOrgUnit('BULK_DISASSOCIATE_UNIT'), isNull);

          // Verify all 100 users are disassociated (orgUnitId becomes null)
          final dbUsersAfter = await dbService.getAllUsers();
          final assignedAfter = dbUsersAfter
              .where((u) => u.orgUnitId == 'BULK_DISASSOCIATE_UNIT')
              .length;
          expect(assignedAfter, equals(0));

          // Spot check a few users
          for (int i in [0, 25, 50, 75, 99]) {
            final user = await dbService.getUser('bulk.user.$i@vetter.com');
            expect(user!.orgUnitId, isNull);
          }
        },
      );
    });
  });
}
