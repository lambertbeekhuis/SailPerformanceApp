import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const SailPerformanceApp());
}

class SailPerformanceApp extends StatelessWidget {
  const SailPerformanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SailPerformance',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Placeholder home screen. Live NMEA, polar, and session features come later.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SailPerformance'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Text(
                'SailPerformance',
                style: textTheme.headlineMedium,
                textAlign: .center,
              ),
              const SizedBox(height: 12),
              Text(
                'Scaffold ready. Connect NMEA and build the sailing dashboard next.',
                style: textTheme.bodyLarge,
                textAlign: .center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
