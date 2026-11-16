import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/nmea_data_source.dart';
import '../../nmea/sailing_snapshot.dart';
import '../../providers/nmea_providers.dart';

/// Minimal live dashboard: large Speed + Wind, File/Live switch.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Keep the screen awake while viewing live data (requirements §2).
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(sailingSnapshotProvider);
    final status = ref.watch(nmeaSourceStatusProvider);
    final kind = ref.watch(nmeaSourceKindProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('SailPerformance'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: SegmentedButton<NmeaSourceKind>(
                segments: const [
                  ButtonSegment(
                    value: NmeaSourceKind.file,
                    label: Text('File'),
                    icon: Icon(Icons.folder_open, size: 18),
                  ),
                  ButtonSegment(
                    value: NmeaSourceKind.live,
                    label: Text('Live'),
                    icon: Icon(Icons.wifi, size: 18),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (next) {
                  final value = next.first;
                  unawaited(
                    ref.read(sailingSnapshotProvider.notifier).setKind(value),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              _StatusBanner(status: status),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 560;
                    final speed = _SpeedPanel(snapshot: snapshot);
                    final wind = _WindPanel(snapshot: snapshot);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: .stretch,
                        children: [
                          Expanded(child: speed),
                          const SizedBox(width: 16),
                          Expanded(child: wind),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Expanded(child: speed),
                        const SizedBox(height: 16),
                        Expanded(child: wind),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aid only — not a navigation instrument.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: .center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final NmeaSourceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = status.kind == NmeaSourceKind.live;
    final color = switch (status.state) {
      NmeaConnectionState.streaming => scheme.primary,
      NmeaConnectionState.error => scheme.error,
      NmeaConnectionState.connecting => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              isLive ? Icons.wifi : Icons.play_circle_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${status.kind.label}: ${status.summary}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({required this.snapshot});

  final SailingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final preferred = snapshot.preferredSpeed;
    final label = snapshot.preferredSpeedLabel;
    final subtitle = snapshot.stw != null && snapshot.sog != null
        ? 'SOG ${snapshot.sog!.value.toStringAsFixed(1)} kn'
        : null;

    return _MetricPanel(
      title: label,
      value: preferred?.value,
      unit: 'kn',
      subtitle: subtitle,
    );
  }
}

class _WindPanel extends StatelessWidget {
  const _WindPanel({required this.snapshot});

  final SailingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final aws = snapshot.aws?.value;
    final awa = snapshot.awaSigned;
    final tws = snapshot.tws?.value;
    final twa = snapshot.twaSigned?.value;

    String? awaText;
    if (awa != null) {
      final side = awa >= 0 ? 'S' : 'P';
      awaText = 'AWA ${awa.abs().toStringAsFixed(0)}° $side';
    }

    String? trueText;
    if (tws != null && twa != null) {
      final side = twa >= 0 ? 'S' : 'P';
      trueText =
          'TWS ${tws.toStringAsFixed(1)}  TWA ${twa.abs().toStringAsFixed(0)}° $side';
    }

    return _MetricPanel(
      title: 'AWS',
      value: aws,
      unit: 'kn',
      subtitle: [
        ?awaText,
        ?trueText,
      ].join(' · '),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.title,
    required this.value,
    required this.unit,
    this.subtitle,
  });

  final String title;
  final double? value;
  final String unit;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = value != null;
    final valueColor =
        hasValue ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: .circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: .scaleDown,
              alignment: .centerLeft,
              child: Row(
                crossAxisAlignment: .baseline,
                textBaseline: .alphabetic,
                children: [
                  Text(
                    hasValue ? value!.toStringAsFixed(1) : '—',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: valueColor,
                      fontWeight: .w600,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: valueColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
