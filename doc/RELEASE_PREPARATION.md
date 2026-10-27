# Release Preparation

## Checklist for a release

1. **Version**
   - Bump `version:` in `pubspec.yaml` (semantic versioning: layout or API changes that
     alter printed output are at least a minor bump).
   - Set `s.version` in `ios/ntbp_plugin.podspec` and `version` in `android/build.gradle`
     to the same value.
   - Add a dated entry at the top of `CHANGELOG.md`.
2. **Quality**
   - `flutter analyze` clean for `lib/` and `test/`.
   - `flutter test` green.
   - `cd example && flutter analyze && flutter test`.
   - `cd example && flutter build apk --debug` and `flutter build ios --no-codesign --debug`.
   - Print a sample label and a 3 label series on the XP-420B from both platforms.
3. **Docs**
   - `README.md` quick start matches the API.
   - `doc/API_REFERENCE.md` lists every public method.
   - `doc/INTEGRATION_GUIDE.md` steps still work on a fresh project.
4. **Package**
   - `flutter pub publish --dry-run` reports 0 warnings and an archive of about 1 MB.
     If it is tens of megabytes, `build/` leaked in: check `.pubignore`.
   - `.pubignore` excludes `sdks/`, `asset/`, `CLAUDE.md` and every build directory.
5. **Git**
   - Commit, push the feature branch, fast-forward `main`, push `main`.
   - Tag: `git tag v3.0.0 && git push origin v3.0.0`.
6. **Publish**
   - `flutter pub publish` (needs the pub.dev uploader account).
   - Create the GitHub release from the tag with the changelog entry as the body.

## 3.0.0 release notes

**Xprinter XP-420B support with a cargo shipment label layout.**

- Cargo label: brand name and logo header, booking and item references, QR summary,
  sender and receiver, destination / weight / package, source / date, cargo name.
- Layouts rendered to TSPL in Dart; identical output on Android and iOS.
- Transport through the Xprinter vendor SDKs (bundled): classic Bluetooth on Android,
  BLE on iOS.
- Printer status query, one-time gap calibration, series printing that stops at the first
  printer error and reports what printed.
- Android runtime permissions requested by the plugin.
- Fixes: invalid TSPL commands removed, no more blank labels between prints, quote
  escaping, iOS three-line label and device address, typed channel payloads.

Breaking changes from 2.x: Android `minSdk 21`; `getPrinterStatus()` returns a decoded map;
`serviceType` → `source` in the cargo model (JSON with `serviceType` is still read).

## Supported printers

- Xprinter XP-420B (primary target, 203 dpi, 4 inch)
- N41 / N42 and other TSPL label printers for the legacy three-line layout
- Media: die-cut gap labels, black-mark paper, continuous paper

## Requirements

- Flutter 3.19+, Dart 3.0+
- Android 5.0 (API 21)+
- iOS 12.0+, real device for Bluetooth

## License

MIT, see `LICENSE`.
