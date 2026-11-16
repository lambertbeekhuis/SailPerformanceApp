import 'package:flutter_test/flutter_test.dart';

import 'package:sail_performance/main.dart';

void main() {
  testWidgets('Home screen shows SailPerformance placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const SailPerformanceApp());

    expect(find.text('SailPerformance'), findsWidgets);
    expect(
      find.textContaining('Scaffold ready'),
      findsOneWidget,
    );
  });
}
