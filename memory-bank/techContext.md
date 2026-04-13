# Technical Context

## Technology Stack

### Core Framework

- **Flutter**: 3.0.0+
- **Dart**: 3.0.0+
- **Material Design**: Material 3 (useMaterial3: true)

### Dependencies

#### Production Dependencies

```yaml
flutter: (sdk)
cupertino_icons: ^1.0.8
audioplayers: ^6.5.1
equatable: ^2.0.8
objective_c: 9.1.0  # pinned — workaround for iOS validation warning, see test/objective_c_test.dart
```

#### Development Dependencies

```yaml
flutter_test: (sdk)
flutter_lints: ^6.0.0
test: ^1.29.0
pub_api_client: ^3.2.0
mocktail: ^1.0.5       # mock AudioPlayer in widget tests (no code generation)
fake_async: ^1.3.3     # control Timer/Future.delayed in widget tests
```

### Audio Package

#### audioplayers ^6.5.1

- Cross-platform audio playback
- Supports MP3 format on both iOS and Android
- Event-based completion notification
- Asset source support for bundled audio files

Key features used:

- `AssetSource()` for playing bundled audio
- `onPlayerComplete` stream for awaiting playback completion
- `stop()` for ensuring clean state between plays

## Development Environment

### Platform Requirements

- **Development**: Linux VM (sandbox environment for AI agent work)
- **Building**: macOS with Xcode (required for iOS builds)
- **Sync Method**: rsync with .gitignore and .rsyncignore filters

### IDE Support

- Primary: Cursor IDE with custom rules and commands
- iOS Build: Xcode (for archiving and TestFlight upload)
- Android: Android Studio capable (though Android not current focus)

### Project Structure

```text
multi-timer/
  ├── .cursor/                    # Cursor IDE configuration
  │   ├── commands/general/       # Custom IDE commands
  │   └── rules/general/          # Agent behavior rules
  ├── android/                    # Android platform code
  ├── assets/                     # Audio files (gong, instructions)
  │   ├── gong.mp3
  │   ├── debug/
  │   └── release/
  ├── docs/
  │   ├── appstore-submission-de-DE/  # App Store submission materials (German)
  │   ├── architecture/               # Architecture documentation and ADRs
  │   └── features/                   # Feature documentation
  ├── ios/                        # iOS platform code
  │   └── Runner.xcodeproj/
  ├── lib/
  │   ├── main.dart              # App entry point + MultiTimerApp only
  │   ├── timer_screen.dart      # TimerScreen (StatefulWidget) + _TimerScreenState
  │   ├── constants.dart         # kGongDurationMs, kGongAudioFile
  │   ├── session_data.dart      # SessionData model
  │   ├── timer_schedule.dart    # Pure timing calculation
  │   ├── timer_event.dart       # Abstract base event
  │   ├── exercise_finished_event.dart
  │   └── playback_requested_event.dart
  ├── pubspec.yaml               # Dependencies and assets
  └── README.md
```

## Platform Configuration

### iOS

- **Project**: Runner.xcodeproj (workspace-based)
- **Signing**: Requires distribution certificate for TestFlight
- **Bundle ID**: systems.boos.multiTimer (registered in Apple Developer portal)
- **Deployment Target**: Supports recent iOS versions
- **Capabilities**: Audio playback (configured)

### Android

- **Build**: Gradle (Kotlin DSL)
- **Build files**: build.gradle.kts
- **Current status**: Configured but not deployment focus

## Audio Assets

### File Formats

- **Format**: MP3 (universally supported)
- **Gong duration**: 6080ms (hardcoded constant)
- **Instruction durations**: Measured and hardcoded per file
  - ganzkoerperatmung.mp3: 8000ms
  - atem-halten.mp3: 8700ms
  - wellenatmen.mp3: 9000ms
  - nachspueren.mp3: 5600ms

### Asset Registration

All audio files must be declared in pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/gong.mp3
    - assets/debug/session1.mp3
    - assets/debug/session2.mp3
    - assets/release/ganzkoerperatmung.mp3
    - assets/release/atem-halten.mp3
    - assets/release/wellenatmen.mp3
    - assets/release/nachspueren.mp3
```

## Development Tools

### Version Control

- **Git**: Primary version control
- **Conventional Commits**: Enforced (feat:, fix:, docs:, refactor:, test:, ci:)
- **Co-authored commits**: AI agent contributions tracked

### Code Quality

- **flutter_lints**: ^6.0.0
- **analysis_options.yaml**: Configured linting rules
- **Dart formatter**: Standard formatting enforced

### Development Workflow

1. **Edit**: AI agent in Linux VM
2. **Sync**: rsync or git to Mac
3. **Build**: `flutter build ios` or `flutter run` on Mac
4. **Test**: Physical iPhone or iOS Simulator
5. **Commit**: Git with conventional commit messages

### CLI vs Xcode GUI builds

`flutter build ios` and `flutter run` invoke `xcodebuild` with their own
build settings that override project defaults. Xcode's Product → Build uses
project settings directly. This means issues like sandboxing (see Known
Limitations) only surface when building via Xcode GUI, not via Flutter CLI.

## Testing Strategy

### Manual Testing

- Physical iPhone device (USB connection)
- iOS Simulator (iOS 26.0 runtime installed)
- Debug mode with 16-second sessions for rapid iteration
- Free Apple Developer account sufficient for device testing

### Automated Testing

Three-layer strategy accepted (ADR-002):

- **Unit tests** — `test/unit/timer_schedule_test.dart` — complete.
  Run with: `flutter test test/unit/`
- **Widget tests** — `test/widget/timer_screen_test.dart` — in progress.
  `MockAudioPlayer` (mocktail), `fake_async` in place. First test green:
  verifies instruction audio on Start tap. Gong + completion scenarios pending.
  Key patterns: `setUpAll` for `registerFallbackValue`, `captureAny()` +
  `isA<AssetSource>().having(...)`, drain with `pump(Duration(seconds: 140))`.
  Run with: `flutter test test/widget/`
- **Integration test** — `test/objective_c_test.dart` — checks
  whether `objective_c` package pin can be removed. Run with:
  `flutter test test/objective_c_test.dart` (makes network call)
- **Manual protocol** — screen lock on real devices before each
  release; see `docs/architecture/concepts/test-strategy.md`

## Build Modes

### Debug

- Session durations: 16-17 seconds each
- Total sequence: ~2 minutes
- Enables rapid development iteration
- Activated via `kDebugMode` constant

### Release

- Session durations: 300-60-300-60-300-120-60 seconds
- Total sequence: 20 minutes
- Production breathing exercise timing
- Default for production builds

## Technical Constraints

### Known Limitations

1. **Timer Reliability**: App must remain in foreground with screen unlocked
   (documented in ADR-001)
2. **Audio Format**: MP3 works for current implementation; iOS notifications
   would require AIFF conversion
3. **Single Platform Focus**: iOS only for current iteration
4. **Network**: App fully offline; no network requirements
5. **Xcode GUI Sandboxing**: Since Xcode 15,
   `ENABLE_USER_SCRIPT_SANDBOXING` defaults to `YES` for new projects.
   CocoaPods script phases don't declare all inputs/outputs, causing
   "located outside of the allowed root paths" errors when building via
   Product → Build. Fix: set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in
   Podfile `post_install` hook. Reference:
   [CocoaPods #11946](https://github.com/CocoaPods/CocoaPods/issues/11946)

### Future Technical Considerations

If implementing ADR-001 solution (notifications):

- Add `flutter_local_notifications` dependency
- Convert gong.mp3 to gong.aiff for iOS
- Add notification permissions
- Platform-specific configuration (AndroidManifest.xml, Info.plist)
- Timezone package dependency

## Deployment

### Current Status

- Development builds: Working on iPhone via Xcode
- TestFlight: ✅ Deployed and beta testers invited
- App Store: Not applicable (pending beta feedback)

### Deployment Guide

Complete TestFlight deployment process documented in `docs/appstore-submission-de-DE/README.md`

### TestFlight Requirements

1. Paid Apple Developer Program membership ✅
2. App Store Connect app record ✅ ("Multi Timer für Atempraxis")
3. Distribution certificate and provisioning profile ✅
4. Unique bundle identifier ✅ (systems.boos.multiTimer)
5. App icon (1024x1024) ✅
6. Privacy policy URL (if app collects data) ✅ (no data collection)
7. Export compliance information ✅ (handled during upload)

## Tool Usage Patterns

### Rsync Synchronization

Used to sync from Linux VM to Mac:

```bash
rsync -avz \
  --exclude='.git' \
  --filter=':- .gitignore' \
  --filter=':- .rsyncignore' \
  $USER@$IPV4_ADDRESS:$MULTI_TIMER_DIR/ ./
```

Preserves git repository while syncing code changes.

### Flutter Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device
flutter build ios        # Build iOS release
```

### Xcode Usage

- Open: Runner.xcworkspace (not .xcodeproj directly)
- Signing: Configure in Runner target settings
- Archive: Product → Archive (for TestFlight)
- Upload: Window → Organizer → Upload to App Store
