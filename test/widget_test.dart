// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_gastos.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_ventas.dart';
import 'package:shawarma_pos_nuevo/main.dart';
import 'mock.dart';

void main() {
  testWidgets('App starts and shows MyApp widget', (WidgetTester tester) async {
    await setupFirebaseCoreMocks(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>(create: (_) => AuthService()),
            Provider<CajaService>(create: (_) => CajaService()),
            Provider<ServicioVentas>(create: (_) => ServicioVentas()),
            Provider<ServicioGastos>(create: (_) => ServicioGastos()),
          ],
          child: const MyApp(), // <- antes decía ShawarmaOxa()
        ),
      );

      expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
