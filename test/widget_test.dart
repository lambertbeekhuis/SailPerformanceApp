import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard shows SailPerformance and File/Live switch',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SailPerformanceApp(),
      ),
    );
    // Allow microtask restart + first file tick without settling forever
    // (file source uses a periodic timer).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('SailPerformance'), findsWidgets);
    expect(find.text('File'), findsWidgets);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('AWA'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('TWD'), findsOneWidget);
    expect(find.byTooltip('Set reference now'), findsOneWidget);
    expect(
      find.textContaining('Aid only'),
      findsOneWidget,
    );
  });
}
