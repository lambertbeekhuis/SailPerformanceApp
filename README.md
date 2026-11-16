# SailPerformance

iPhone-first Flutter app that reads NMEA 0183 sailing data (file replay today, live Wi‑Fi TCP next) and shows a readable live dashboard.

## Run the **app** in the iOS Simulator

Booting the Simulator alone only shows the home screen. You still need Flutter to install and launch SailPerformance:

```bash
cd ~/Sites/SailPerformanceApp

# Optional: boot a simulator first
open -a Simulator
# or: xcrun simctl boot "iPhone 16"

# This installs and opens the app UI (required)
flutter run
# or pick a device: flutter devices && flutter run -d <device-id>
```

From Xcode: open `ios/Runner.xcworkspace`, select the **Runner** scheme and a simulator, then Run.

`open -a Simulator` by itself does **not** launch SailPerformance.

If `flutter run` fails with “No Xcode build settings” / no Simulator destination, Xcode’s SDK (e.g. iOS 26.5) may be newer than the installed Simulator runtimes. Install the matching platform in **Xcode → Settings → Components** (or `xcodebuild -downloadPlatform iOS`), then retry `flutter run`.

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
