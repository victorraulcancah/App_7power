import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/core/constants/app_constants.dart';
import 'package:appecommerce/main.dart';

void main() {
  testWidgets('Muestra la página de inicio', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
