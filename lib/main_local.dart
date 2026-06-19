import 'main.dart';
import 'firebase_options.dart';
import 'core/providers/providers.dart';

void main() async {
  final config = AppConfig(
    environment: AppEnvironment.local,
    firebaseOptions: DefaultFirebaseOptions.local,
    useEmulator: true,
  );
  await runCapplaApp(config);
}
