// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appConfigHash() => r'd510e92fbe3a878a2a50f257a232c7a4f6464403';

/// See also [appConfig].
@ProviderFor(appConfig)
final appConfigProvider = AutoDisposeProvider<AppConfig>.internal(
  appConfig,
  name: r'appConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppConfigRef = AutoDisposeProviderRef<AppConfig>;
String _$firebaseAuthHash() => r'3792352c2389d7899f6268409ad5735e277ee114';

/// See also [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = AutoDisposeProvider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = AutoDisposeProviderRef<FirebaseAuth>;
String _$firestoreHash() => r'f43ae859b87a46e5d91debe76aa63a9848a23d52';

/// See also [firestore].
@ProviderFor(firestore)
final firestoreProvider = AutoDisposeProvider<FirebaseFirestore>.internal(
  firestore,
  name: r'firestoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreRef = AutoDisposeProviderRef<FirebaseFirestore>;
String _$authStateSyncHash() => r'240b69af758a2bf6f14e43b440033db3673445db';

/// See also [authStateSync].
@ProviderFor(authStateSync)
final authStateSyncProvider = StreamProvider<UserModel?>.internal(
  authStateSync,
  name: r'authStateSyncProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateSyncHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateSyncRef = StreamProviderRef<UserModel?>;
String _$currentUserHash() => r'5f252cc00883c62b1c9201fc9ef3ba34f5ead214';

/// See also [CurrentUser].
@ProviderFor(CurrentUser)
final currentUserProvider = NotifierProvider<CurrentUser, UserModel?>.internal(
  CurrentUser.new,
  name: r'currentUserProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentUser = Notifier<UserModel?>;
String _$resetPasswordEmailHash() =>
    r'e23347f12ecebc7dc5bbf97513da7b3bdac2d7c1';

/// See also [ResetPasswordEmail].
@ProviderFor(ResetPasswordEmail)
final resetPasswordEmailProvider =
    AutoDisposeNotifierProvider<ResetPasswordEmail, String>.internal(
      ResetPasswordEmail.new,
      name: r'resetPasswordEmailProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$resetPasswordEmailHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ResetPasswordEmail = AutoDisposeNotifier<String>;
String _$resetPasswordCodeHash() => r'd08d28d5ec03a95e8e5923d32727c4548bcd033b';

/// See also [ResetPasswordCode].
@ProviderFor(ResetPasswordCode)
final resetPasswordCodeProvider =
    AutoDisposeNotifierProvider<ResetPasswordCode, String>.internal(
      ResetPasswordCode.new,
      name: r'resetPasswordCodeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$resetPasswordCodeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ResetPasswordCode = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
