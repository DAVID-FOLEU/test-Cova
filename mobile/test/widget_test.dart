import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('shows the Cova authentication screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Connexion Cova'), findsOneWidget);
    expect(find.text("Pas de compte ? S'inscrire"), findsOneWidget);
  });
}
