import 'main.dart';
import 'firebase_options.dart';
import 'core/providers/providers.dart';

void main() async {
  final config = AppConfig(
    environment: AppEnvironment.staging,
    firebaseOptions: DefaultFirebaseOptions.staging,
    useEmulator: false,
  );
  await runCapplaApp(config);
}
