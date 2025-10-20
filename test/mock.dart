import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

// Simula la inicialización de Firebase para las pruebas
Future<T> setupFirebaseCoreMocks<T>(Future<T> Function() testRunner) async {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // Asegúrate de que las pruebas se inicialicen correctamente
  await Firebase.initializeApp(
    // Simula la inicialización de Firebase
    options: const FirebaseOptions(
      apiKey: 'mock-api-key',
      appId: 'mock-app-id',
      messagingSenderId: 'mock-sender-id',
      projectId: 'mock-project-id',
    ),
  );
  return await testRunner();
}
