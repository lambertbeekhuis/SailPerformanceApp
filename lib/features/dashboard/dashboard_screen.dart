import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/nmea_data_source.dart';
import '../../nmea/course_display.dart';
import '../../nmea/sailing_snapshot.dart';
import '../../providers/nmea_providers.dart';

/// Live dashboard: Speed, AWA, AWS(+TWS), Heading/COG, TWD + lift/header.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _staleTicker;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake while viewing live data (requirements §2).
    unawaited(WakelockPlus.enable());
    // Rebuild periodically so stale values grey out without new NMEA.
    _staleTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _staleTicker?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(sailingSnapshotProvider);
    final status = ref.watch(nmeaSourceStatusProvider);
    final kind = ref.watch(nmeaSourceKindProvider);
    final course = ref.watch(courseDisplayProvider);
    final pinned = ref.watch(windReferencePinnedProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              _StatusBanner(status: status),
              const SizedBox(height: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final tiles = _buildTiles(
                      snapshot: snapshot,
                      course: course,
                      now: now,
                      pinned: pinned,
                      onSetReference: () {
                        ref
                            .read(sailingSnapshotProvider.notifier)
                            .setWindReferenceNow();
                      },
                    );
                    return Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Expanded(child: tiles[i]),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
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

  List<Widget> _buildTiles({
    required SailingSnapshot snapshot,
    required CourseDisplay course,
    required DateTime now,
    required bool pinned,
    required VoidCallback onSetReference,
  }) {
    final awa = snapshot.awaSigned;
    String? awaSide;
    if (awa != null) {
      awaSide = awa >= 0 ? 'Stbd' : 'Port';
    }

    final speed = snapshot.preferredSpeed;
    final speedHint = snapshot.stw != null
        ? (snapshot.sog != null
            ? 'STW · SOG ${snapshot.sog!.value.toStringAsFixed(1)}'
            : 'STW')
        : (snapshot.sog != null ? 'SOG fallback' : null);

    final tws = snapshot.tws;
    final twsStale =
        tws == null || tws.isStale(now, kDefaultStaleTimeout);
    final twsLabel = (!twsStale)
        ? 'TWS ${tws.value.toStringAsFixed(1)} kn'
        : null;

    return [
      _MetricTile(
        title: 'Speed',
        value: speed?.value,
        unit: 'kn',
        timed: speed,
        now: now,
        subtitle: speedHint,
        fractionDigits: 1,
      ),
      _MetricTile(
        title: 'AWA',
        value: awa?.abs(),
        unit: '°',
        timed: snapshot.awaDegreesFromBow,
        now: now,
        subtitle: awaSide,
        fractionDigits: 0,
      ),
      _MetricTile(
        title: 'AWS',
        value: snapshot.aws?.value,
        unit: 'kn',
        timed: snapshot.aws,
        now: now,
        subtitle: twsLabel,
        fractionDigits: 1,
      ),
      _MetricTile(
        title: course.sourceLabel,
        value: course.degrees,
        unit: '°',
        timed: course.value,
        now: now,
        subtitle: course.mode == CourseDisplayMode.preferHeading
            ? (course.sourceLabel == 'Heading'
                ? 'prefers Heading'
                : 'COG (no Heading)')
            : null,
        fractionDigits: 0,
      ),
      _TwdTile(
        snapshot: snapshot,
        now: now,
        pinned: pinned,
        onSetReference: onSetReference,
      ),
    ];
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
        padding: const EdgeInsets.only(bottom: 6),
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

/// Full-width horizontal instrument band: label left, large value right.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.now,
    this.timed,
    this.subtitle,
    this.fractionDigits = 1,
  });

  final String title;
  final double? value;
  final String unit;
  final DateTime now;
  final TimedValue? timed;
  final String? subtitle;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stale = timed == null ||
        timed!.isStale(now, kDefaultStaleTimeout);
    final hasValue = value != null && !stale;
    final valueColor =
        hasValue ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: .circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: .center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: .w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: .scaleDown,
                alignment: .centerRight,
                child: Row(
                  mainAxisAlignment: .end,
                  crossAxisAlignment: .baseline,
                  textBaseline: .alphabetic,
                  children: [
                    Text(
                      hasValue
                          ? value!.toStringAsFixed(fractionDigits)
                          : '—',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: valueColor,
                        fontWeight: .w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unit,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: valueColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwdTile extends StatelessWidget {
  const _TwdTile({
    required this.snapshot,
    required this.now,
    required this.pinned,
    required this.onSetReference,
  });

  final SailingSnapshot snapshot;
  final DateTime now;
  final bool pinned;
  final VoidCallback onSetReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timed = snapshot.twd;
    final stale =
        timed == null || timed.isStale(now, kDefaultStaleTimeout);
    final hasValue = timed != null && !stale;
    final valueColor =
        hasValue ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35);
    final lift = snapshot.liftHeaderLabel;
    final liftColor = _liftColor(scheme, lift, hasValue);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: .circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: .center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TWD',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 1.1,
                            fontWeight: .w600,
                          ),
                          overflow: .ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onSetReference,
                        tooltip: pinned
                            ? 'Reference pinned — tap to re-pin now'
                            : 'Set reference now',
                        visualDensity: .compact,
                        iconSize: 20,
                        padding: .zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    pinned ? 'Pinned reference' : 'Rolling ~12 min reference',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: .scaleDown,
                alignment: .centerRight,
                child: Row(
                  mainAxisAlignment: .end,
                  crossAxisAlignment: .baseline,
                  textBaseline: .alphabetic,
                  children: [
                    Text(
                      hasValue
                          ? timed.value.toStringAsFixed(0)
                          : '—',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: valueColor,
                        fontWeight: .w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '°',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: valueColor.withValues(alpha: 0.7),
                      ),
                    ),
                    if (lift != null && hasValue) ...[
                      const SizedBox(width: 12),
                      Text(
                        lift,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: liftColor,
                          fontWeight: .w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _liftColor(ColorScheme scheme, String? lift, bool hasValue) {
    if (!hasValue || lift == null) {
      return scheme.onSurface.withValues(alpha: 0.35);
    }
    if (lift.startsWith('Lift')) {
      return const Color(0xFF1B7F4A);
    }
    if (lift.startsWith('Header')) {
      return const Color(0xFFB3261E);
    }
    return scheme.onSurfaceVariant;
  }
}
