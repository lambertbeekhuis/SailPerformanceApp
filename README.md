# SailPerformance

iPhone-first Flutter app that reads NMEA 0183 sailing data (file replay today, live Wi‑Fi TCP next) and shows a readable live dashboard.

## Run the **app** in the iOS Simulator

Booting the Simulator alone only shows the home screen. You still need Flutter to install and launch SailPerformance.

### Working recipe (this Mac)

Default `xcode-select` points at **Xcode 26.6** (iOS **26.5** SDK), but the matching **iOS 26.5 Simulator** runtime is not installed yet (only ≤26.3). Until that runtime is installed, use **Xcode 16.4** + an **iOS 18.6** simulator:

```bash
cd ~/Sites/SailPerformanceApp

# Prefer Xcode 16.4 for Flutter until iOS 26.5 runtime is installed
export DEVELOPER_DIR=/Applications/Xcode16.app/Contents/Developer

# Boot an iOS 18.6 simulator (iPhone 16e works)
open -a Simulator
xcrun simctl boot "iPhone 16e" 2>/dev/null || true
# If several iPhone 16e exist, pick the iOS 18.6 one explicitly:
#   flutter devices
#   flutter run -d 3C70161C-14F1-4F3D-B855-E529F278072E

flutter run -d 3C70161C-14F1-4F3D-B855-E529F278072E
```

Optional one-time system switch (needs your Mac password):

```bash
sudo xcode-select -s /Applications/Xcode16.app/Contents/Developer
flutter run -d 3C70161C-14F1-4F3D-B855-E529F278072E
```

### Restore Xcode 26.6 later (after iOS 26.5 runtime)

```bash
# Non-interactive (preferred; ~8.5 GB — use a stable network, not a flaky hotspot):
xcodebuild -downloadPlatform iOS

# Or interactive: Xcode → Settings → Platforms / Components → download iOS 26.5
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
flutter devices   # pick a device on iOS 26.5 (or matching) runtime
flutter run -d <device-id>
```

From Xcode 16: open `ios/Runner.xcworkspace`, select **Runner** + an iOS 18.x simulator, then Run.

`open -a Simulator` by itself does **not** launch SailPerformance.

## Debug data source

On the dashboard AppBar: **File** | **Live** segmented control.

- **File** (default): replays `assets/nmea/sample_sailing.nmea` into the same parser pipeline as live.
- **Live**: TCP client skeleton (`dart:io` `Socket`). With empty host it stays on “Not connected — configure host:port later”. Host/port providers live in `lib/providers/nmea_providers.dart`.

## Develop

```bash
flutter pub get
flutter analyze
flutter test
```

## Layout

- `lib/nmea/` — checksum, parser, sailing snapshot (STW/SOG, AWS/AWA, computed TWS/TWA)
- `lib/data/` — `NmeaDataSource` interface, `FileNmeaSource`, `LiveTcpNmeaSource`
- `lib/features/dashboard/` — large Speed + Wind UI, screen awake via `wakelock_plus`
- `assets/nmea/sample_sailing.nmea` — synthetic log with valid checksums (MWV, VHW, VTG, RMC)
- `assets/branding/app_icon_1024.png` — AppIcon source (also wired into iOS/Android launchers)
