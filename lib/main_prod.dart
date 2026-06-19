import 'main.dart';
import 'firebase_options.dart';
import 'core/providers/providers.dart';

void main() async {
  final config = AppConfig(
    environment: AppEnvironment.prod,
    firebaseOptions: DefaultFirebaseOptions.prod,
    useEmulator: false,
  );
  await runCapplaApp(config);
}
