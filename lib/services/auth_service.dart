import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/providers/providers.dart';
import 'database/database_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final DatabaseService _dbService;
  final bool _useEmulator;
  final Ref _ref;

  AuthService(this._auth, this._dbService, this._ref, {required this._useEmulator});

  bool get hasCurrentUser {
    return _auth.currentUser != null;
  }

  Stream<UserModel?> get userStateChanges {
    return _auth.authStateChanges().asyncExpand<UserModel?>((authUser) {
      debugPrint('userStateChanges: authUser=${authUser?.email}');
      if (authUser == null) {
        debugPrint('userStateChanges: authUser is null, yielding null');
        return Stream.value(null);
      }
      final String? email = authUser.email;
      if (email == null || email.isEmpty) {
        debugPrint('userStateChanges: email is empty, yielding null');
        return Stream.value(null);
      }
      debugPrint('userStateChanges: watching user by email=$email');
      return _dbService.watchUserByEmail(email);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final user = await _dbService.getUser(email);
    if (user == null) {
      await signOut();
      throw Exception('User data not found in database.');
    }
    if (user.status == 'Inactive') {
      await signOut();
      throw Exception('Your account is Inactive. Access denied.');
    }
    _ref.read(currentUserProvider.notifier).update(user);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _ref.read(currentUserProvider.notifier).update(null);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> createUser(UserModel user, String password) async {
    try {
      // In testing (e.g. using fake/mock auth), we can register directly.
      // Otherwise, we initialize a secondary Firebase App in production to avoid signing out the current admin.
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
      if (e.toString().contains('email-already-in-use')) {
        // Ignore and proceed to save DB profile
      } else {
        // Fall back to direct mock/fake auth user creation in tests where Firebase is not initialized
        try {
          await _auth.createUserWithEmailAndPassword(
            email: user.email,
            password: password,
          );
        } catch (mockError) {
          if (!mockError.toString().contains('email-already-in-use')) {
            rethrow;
          }
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
  return AuthService(auth, dbService, ref, useEmulator: config.useEmulator);
});
