import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/providers.dart';

void main() async {
  // Default entry point runs the local environment (emulator)
  final config = AppConfig(
    environment: AppEnvironment.local,
    firebaseOptions: DefaultFirebaseOptions.local,
    useEmulator: true,
  );
  await runCapplaApp(config);
}

Future<void> runCapplaApp(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  await Firebase.initializeApp(options: config.firebaseOptions);

  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWithValue(config)],
  );

  try {
    await container.read(databaseServiceProvider).seedUsers();
  } catch (e, stack) {
    debugPrint('DATABASE SEEDING ERROR: $e');
    debugPrint('$stack');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CapplaApp(),
    ),
  );
}

class CapplaApp extends ConsumerWidget {
  const CapplaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start listening to the auth state sync stream
    ref.watch(authStateSyncProvider);

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Cappla App',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
    );
  }
}
