// File: lib/core/providers/auth_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../firebase_options.dart';


part 'auth_providers.g.dart';

enum AppEnvironment { local, dev, staging, prod }

class AppConfig {
  final AppEnvironment environment;
  final FirebaseOptions firebaseOptions;
  final bool useEmulator;
  final bool isTesting;

  const AppConfig({
    required this.environment,
    required this.firebaseOptions,
    required this.useEmulator,
    this.isTesting = false,
  });
}

@riverpod
AppConfig appConfig(AppConfigRef ref) {
  return const AppConfig(
    environment: AppEnvironment.local,
    firebaseOptions: DefaultFirebaseOptions.local,
    useEmulator: true,
  );
}

@riverpod
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  final auth = FirebaseAuth.instance;
  final config = ref.watch(appConfigProvider);
  if (config.useEmulator) {
    try {
      auth.useAuthEmulator('127.0.0.1', 9099);
    } catch (_) {}
  }
  return auth;
}

@riverpod
FirebaseFirestore firestore(FirestoreRef ref) {
  final firestore = FirebaseFirestore.instance;
  final config = ref.watch(appConfigProvider);
  if (config.useEmulator) {
    try {
      firestore.useFirestoreEmulator('127.0.0.1', 8080);
    } catch (_) {}
  }
  return firestore;
}

@Riverpod(keepAlive: true)
class CurrentUser extends _$CurrentUser {
  @override
  UserModel? build() {
    return ref.watch(authStateSyncProvider).valueOrNull;
  }

  void update(UserModel? user) {
    state = user;
  }
}

@Riverpod(keepAlive: true)
Stream<UserModel?> authStateSync(AuthStateSyncRef ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.userStateChanges;
}

@riverpod
class ResetPasswordEmail extends _$ResetPasswordEmail {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

@riverpod
class ResetPasswordCode extends _$ResetPasswordCode {
  @override
  String build() => '123456';

  @override
  set state(String value) => super.state = value;
}
