// File: lib/firebase_options.dart
// Generated for Cappla (Milestone M1)
// Target GCP Project: cappla-app (number: 319249074563)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return dev;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform. '
      'Currently, Cappla only supports Flutter Web.',
    );
  }

  // Local development emulator options (uses demo- prefix)
  static const FirebaseOptions local = FirebaseOptions(
    apiKey: 'local-emulator-key',
    appId: '1:319249074563:web:a1b2c3d4e5f6g7h8i9j0k1',
    messagingSenderId: '319249074563',
    projectId: 'demo-cappla-app',
    authDomain: 'demo-cappla-app.firebaseapp.com',
    storageBucket: 'demo-cappla-app.firebasestorage.app',
  );

  // Dev GCP environment (cappla-app)
  static const FirebaseOptions dev = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'dev-placeholder-key'),
    appId: '1:319249074563:web:a1b2c3d4e5f6g7h8i9j0k1',
    messagingSenderId: '319249074563',
    projectId: 'cappla-app',
    authDomain: 'cappla-app.firebaseapp.com',
    storageBucket: 'cappla-app.firebasestorage.app',
  );

  // Staging GCP environment (placeholder credentials)
  static const FirebaseOptions staging = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'staging-placeholder-key'),
    appId: '1:319249074563:web:a1b2c3d4e5f6g7h8i9j0k2',
    messagingSenderId: '319249074563',
    projectId: 'cappla-app-staging',
    authDomain: 'cappla-app-staging.firebaseapp.com',
    storageBucket: 'cappla-app-staging.firebasestorage.app',
  );

  // Prod GCP environment (placeholder credentials)
  static const FirebaseOptions prod = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'prod-placeholder-key'),
    appId: '1:319249074563:web:a1b2c3d4e5f6g7h8i9j0k3',
    messagingSenderId: '319249074563',
    projectId: 'cappla-app-prod',
    authDomain: 'cappla-app-prod.firebaseapp.com',
    storageBucket: 'cappla-app-prod.firebasestorage.app',
  );
}
