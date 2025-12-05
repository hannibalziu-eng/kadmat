# Build Optimization Guide

## Flutter Build Optimization

### Production Build Commands

**Android APK:**
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

**Android App Bundle (recommended for Play Store):**
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

**iOS:**
```bash
flutter build ios --release --obfuscate --split-debug-info=build/ios/symbols
```

### Optimization Flags

- `--obfuscate`: Minifies code and obscures symbol names
- `--split-debug-info`: Separates debug symbols for crash reporting
- `--tree-shake-icons`: Removes unused Material/Cupertino icons

### pubspec.yaml Optimization

Ensure the following for smaller builds:
```yaml
flutter:
  uses-material-design: true
  # Only include assets you actually use
```

### Code Splitting

For web builds, use deferred imports for large dependencies:
```dart
import 'package:flutter_map/flutter_map.dart' deferred as maps;
```

### Image Optimization

- Use WebP format for images
- Compress all assets before adding to project
- Use `CachedNetworkImage` for remote images

## Size Analysis

Check app size:
```bash
flutter build apk --analyze-size
```

## Performance Profiling

```bash
flutter run --profile
```
