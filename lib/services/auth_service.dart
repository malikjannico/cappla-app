import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../core/providers/providers.dart';
import 'database/database_service.dart';

class AuthService {
  final Object _auth;
  final DatabaseService _dbService;
  final bool _useEmulator;

  AuthService(this._auth, this._dbService, {required this._useEmulator});

  FirebaseAuth get _firebaseAuth => _auth as FirebaseAuth;

  Stream<UserModel?> get userStateChanges {
    final Stream<dynamic> authStateChangesStream;
    if (_auth is FirebaseAuth) {
      authStateChangesStream = _firebaseAuth.authStateChanges();
    } else {
      authStateChangesStream = (_auth as dynamic).authStateChanges() as Stream<dynamic>;
    }
    return authStateChangesStream.asyncExpand<UserModel?>((authUser) {
      if (authUser == null) {
        return Stream.value(null);
      }
      final String? email = authUser.email;
      if (email == null || email.isEmpty) {
        return Stream.value(null);
      }
      return _dbService.watchUserByEmail(email);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_auth is FirebaseAuth) {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } else {
      await (_auth as dynamic).signInWithEmailAndPassword(email: email, password: password);
    }
    final user = await _dbService.getUser(email);
    if (user == null) {
      await signOut();
      throw Exception('User data not found in database.');
    }
    if (user.status == 'Inactive') {
      await signOut();
      throw Exception('Your account is Inactive. Access denied.');
    }
  }

  Future<void> signOut() async {
    if (_auth is FirebaseAuth) {
      await _firebaseAuth.signOut();
    } else {
      await (_auth as dynamic).signOut();
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    if (_auth is FirebaseAuth) {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } else {
      await (_auth as dynamic).sendPasswordResetEmail(email: email);
    }
  }

  Future<void> createUser(UserModel user, String password) async {
    try {
      // For MockFirebaseAuth in E2E tests:
      (_auth as dynamic).registerUser(user.email, password);
    } catch (_) {
      // For real FirebaseAuth:
      // To avoid signing out the current admin user, use a secondary Firebase App.
      try {
        final app = await Firebase.initializeApp(
          name: 'Secondary',
          options: Firebase.app().options,
        );
        try {
          final secondaryAuth = FirebaseAuth.instanceFor(app: app);
          if (_useEmulator) {
            try {
              secondaryAuth.useAuthEmulator('127.0.0.1', 9099);
            } catch (_) {}
          }
          await secondaryAuth.createUserWithEmailAndPassword(
            email: user.email,
            password: password,
          );
        } finally {
          await app.delete();
        }
      } catch (e) {
        if (!e.toString().contains('email-already-in-use')) {
          rethrow;
        }
      }
    }

    await _dbService.saveUser(user);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final dbService = ref.watch(databaseServiceProvider);
  final config = ref.watch(appConfigProvider);
  return AuthService(auth, dbService, useEmulator: config.useEmulator);
});
