import 'package:flutter_test/flutter_test.dart';
import 'package:harlesjujug/main.dart';

void main() {
  testWidgets('SplashScreen loads correctly test', (WidgetTester tester) async {
    await tester.pumpWidget(const HarlesJujugApp());
    expect(find.text('Masuk ke Aplikasi (Login)'), findsOneWidget);
    expect(find.text('SATU APLIKASI, BANYAK SOLUSI'), findsOneWidget);
  });
}
