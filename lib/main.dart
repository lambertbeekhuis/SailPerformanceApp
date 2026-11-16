import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'features/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SailPerformanceApp(),
    ),
  );
}

class SailPerformanceApp extends StatelessWidget {
  const SailPerformanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SailPerformance',
      theme: ThemeData(
        colorScheme: .fromSeed(
          seedColor: const Color(0xFF0B3D5C),
          brightness: .light,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
