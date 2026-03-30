# Progress

## What Works

### Core Functionality ✅

- ✅ Single-button start interface
- ✅ 7-session breathing exercise sequence
- ✅ German audio instruction playback before each session
- ✅ Gong sound at end of each session
- ✅ Black screen with progress bar during exercise
- ✅ Automatic return to start screen after completion
- ✅ Debug mode with shortened timings (16-17 seconds)
- ✅ Release mode with full timings (20 minutes total)

### Audio System ✅

- ✅ Reliable audio playback (fixed race condition)
- ✅ Proper timing coordination (audio + delay + gong)
- ✅ Audio file organization (release/ directory)
- ✅ Audio volume increased for voice instructions (v1.0.0+2)
- ✅ All exercise audios integrated:
  - Ganzkörperatmung (full body breathing)
  - Atem-halten (breath holding)
  - Wellenatmen (wave breathing)
  - Nachspüren (sensing/feeling after)

### Visual Feedback ✅

- ✅ Progress bar fills from bottom to top
- ✅ Semi-transparent purple color on black background
- ✅ Smooth updates (500ms intervals)
- ✅ Accurate progress calculation based on elapsed time

### Development Infrastructure ✅

- ✅ Flutter project structure
- ✅ iOS project configuration
- ✅ Development device deployment
- ✅ Rsync workflow from Linux VM to Mac
- ✅ Git version control with conventional commits
- ✅ Debug/release mode switching
- ✅ Architecture decision documentation (ADR-001 accepted,
  ADR-002 accepted)

## What's Left to Build

### Screen Lock Fix 🚧 (In Progress)

**Goal**: Enable automatic display sleep during 20-minute breathing sequence

**Approach**: Notification-based timing (ADR-001) - Implementation plan

**Implementation Steps**:

0. 🚧 Extract `TimerSchedule` — nearly complete. One item remains
   (see activeContext.md): (0a) wire `_runExerciseSequence()` to
   `TimerSchedule.buildEvents()`. Step 0b done: `SessionData.durationMs`
   is now the backing field; `SessionData` and constants extracted to
   own files (`session_data.dart`, `constants.dart`)
1. ⏳ Foundation Setup - Add dependencies and configuration
2. ⏳ Permission Flow - Request notification permissions
3. ⏳ Single Notification Proof - Validate notifications fire while locked
4. ⏳ Audio Asset Conversion - Convert gong.mp3 to gong.aiff
5. ⏳ Notification with Sound - Validate audio playback
6. ⏳ Schedule Calculation - Pre-calculate all 7 notification times
7. ⏳ Parallel Notification Schedule - Run alongside existing timer
8. ⏳ Replace Timer Logic - Remove old timer approach
9. ⏳ Progress Bar Refinement - Handle screen lock/unlock
10. ⏳ Cleanup & Edge Cases - Cancellation and notification management
11. ⏳ End-to-End Validation - Real-world testing

**Status**: Step 0 in progress (TimerSchedule extraction, see activeContext.md)

**Next TestFlight Release**: Version 1.1.0 with screen lock fix

### Testing Infrastructure 🚧 (In Progress — Step 0)

**Decision**: Three-layer approach (ADR-002 accepted)

**Layers**:

- 🚧 Unit tests — `test/unit/timer_schedule_test.dart` complete for
  `TimerSchedule`. Covers: `ExerciseFinishedEvent` offsets (empty,
  single, three sessions), `PlaybackRequestedEvent` (no sessions,
  single session with/without audio, multi-session offset
  accumulation). All green.
- ⏳ Widget tests — inject `AudioPlayer`, test UI state transitions
  with `fake_async` and `mocktail`. Prerequisite: Step 0.
- ⏳ Manual protocol — screen lock checklist on real devices.
  Prerequisite: ADR-001 implementation complete (Step 11).

**Reference**: `docs/architecture/concepts/test-strategy.md`

**Files added/extracted**:

- `lib/timer_event.dart` — abstract base class (`offsetMs`)
- `lib/exercise_finished_event.dart` — extends `TimerEvent`
- `lib/playback_requested_event.dart` — extends `TimerEvent` (`offsetMs`, `audioFile`)
- `lib/timer_schedule.dart` — pure calculation class, `buildEvents()` returns `List<TimerEvent>`
- `lib/session_data.dart` — `SessionData` extracted from `main.dart`
- `lib/constants.dart` — `kGongDurationMs`, `kGongAudioFile` extracted from `main.dart`
- `test/unit/timer_schedule_test.dart` — unit tests for `TimerSchedule`
- `test/objective_c_test.dart` — retained (reminder to upgrade `objective_c` dep when fixed upstream)

### TestFlight Deployment ✅ (Completed)

**All deployment steps completed successfully**

TestFlight deployment completed. App is live in TestFlight with 2 beta testers invited.

**Key Configuration**:

- Bundle identifier: systems.boos.multiTimer
- App Store Connect record: "Multi Timer für Atempraxis"
- Version: 1.0.0+1
- Git tag: v4 (tracks source code for this build)

**Critical Learnings**:

1. **CocoaPods Integration**: Must run `flutter build ios --release` before archiving in Xcode
2. **MinimumOSVersion Fix**: Flutter's AppFrameworkInfo.plist requires explicit MinimumOSVersion key (commit 383610b)

**Full deployment process documented in**: `docs/appstore-submission-de-DE/README.md`

### Future Enhancements ⏸️ (Pending Further Feedback)
- ⏸️ Android deployment
- ⏸️ Additional breathing exercise sequences
- ⏸️ Customizable timer durations
- ⏸️ Progress tracking/history
- ⏸️ User preferences
- ⏸️ Public App Store release

## Current Status

**Phase**: Implementing screen lock fix based on beta feedback

**Last Completed**: Audio volume increased (v1.0.0+2); deployed to TestFlight Jan 17, 2026

**Next Immediate Task**: Make `AudioPlayer` injectable → add `mocktail` → widget tests → Step 0a (see activeContext.md for full revised sequence)

**Version Tracking**:
- Git tag v4 marks source code for TestFlight build 1.0.0+1
- 1.0.0+2 deployed to TestFlight: audio volume increase
- Working toward version 1.1.0 with screen lock fix

**Blockers**: None

## Known Issues

### In Progress (Being Fixed)

**Screen Lock Timer Failure**

- **Issue**: Timer stops when device screen locks
- **Impact**: 
  - Users must manually disable auto-lock in Settings before each practice
  - Users must remember to re-enable auto-lock after practice
  - **Security Risk**: Forgetting to re-enable leaves device unprotected
- **Root Cause**: iOS/Android suspend apps; `Future.delayed()` stops counting
- **Documented In**: ADR-001
- **Solution**: Use OS-native notifications (implementation plan defined)
- **Beta Feedback**: Testers' most urgent need; #1 priority
- **Status**: Step 0 in progress — completing extraction, then Step 1
- **Target Version**: 1.1.0

### Non-Critical

None currently identified.

## Evolution of Project Decisions

### Initial Implementation → Audio Integration

**Phase 1**: Basic multi-cycle timer with gong sounds

**Evolution**: Added German audio instructions for each exercise type

**Commits**:

- cf36915: feat: integrate exercise-specific audio recordings
- b8d1d9d: feat: play recording at session start (wip)
- a527a13: feat: play optional audio before each exercise session

### Audio Timing Challenges → Precise Coordination

**Challenge**: Maintain accurate session durations while playing variable-length audio files

**Solution Evolution**:

- 3b8c81a: Play audio concurrently with timer (initial approach)
- fae8a9e: Play audio completely before timer starts (sequential approach)
- 09d8815: Subtract audio duration from session delay (precise timing)

**Result**: Sessions now start with audio instruction, followed by calculated silent delay, ending with gong

### Audio Reliability Issues → Race Condition Fix

**Problem**: Some audio files wouldn't play consistently

**Investigation**: commit e2ef21e (test: debug mode plays same audio twice)

**Fix**: commit faed597 (fix: some audios are not played)

**Solution**: Setup `onPlayerComplete` listener BEFORE calling `play()` to avoid race condition

### Basic Progress Indication → Visual Feedback

**Evolution**: commit bd3b760 (feat: display progress bar filling from bottom to top)

**Design Choice**: Bottom-to-top fill with semi-transparent color maintains minimal distraction while providing time awareness

### Development Speed → Debug Mode

**Challenge**: 20-minute sequence too long for rapid iteration

**Solution**: commit c3c2298 (feat: enable rapid testing with debug mode timer acceleration)

**Implementation**: Use `kDebugMode` to switch between 16-second (debug) and full-duration (release) sessions

### Screen Lock Discovery → ADR Documentation

**Discovery**: Timer fails when device screen locks during 5-minute wait

**Response**: Created comprehensive ADR-001 documenting:

- Problem analysis
- 6 potential solutions
- Comparison matrix
- Recommended approach (notifications)
- Migration path

**Decision**: Document and accept for beta; evaluate based on user feedback

### TestFlight Validation → AppFrameworkInfo.plist Fix

**Problem**: First TestFlight upload failed with validation errors (commit 383610b)

**Root Cause**: Flutter's generated AppFrameworkInfo.plist was missing the required MinimumOSVersion key

**Solution**: Added `<key>MinimumOSVersion</key><string>12.0</string>` to match IPHONEOS_DEPLOYMENT_TARGET

**Lesson**: Flutter's iOS framework bundle requires explicit MinimumOSVersion declaration for App Store validation

**Documentation**: Full troubleshooting guide in `docs/appstore-submission-de-DE/README.md`

## Testing History

### Manual Testing Performed

- ✅ Complete 20-minute sequence execution (screen unlocked)
- ✅ Audio instruction playback for all exercise types
- ✅ Gong sound timing
- ✅ Progress bar visual accuracy
- ✅ Debug mode rapid iteration (16-second sessions)
- ✅ Screen lock behavior (confirmed issue)
- ✅ TestFlight beta installation process (both testers)
- ✅ Real-world usage by target users (initial feedback received)

### Testing Gaps

- ⏳ Extended battery usage during session
- ⏳ Behavior with incoming calls/notifications during session
- ⏳ Multiple consecutive sessions
- ⏳ Comprehensive user feedback (ongoing)

## Metrics

### Code Metrics

- **Total Files**: 7 Dart files (main.dart + 6 extracted lib files)
- **Dependencies**: 2 production packages (cupertino_icons, audioplayers)
- **Audio Assets**: 8 files (1 gong + 4 release + 2 debug + 1 unused)
- **Platforms**: iOS (active), Android (configured, not focused)

### Project Metrics

- **Commits**: 32 total
- **Development Time**: ~3-4 weeks (based on commit history)
- **Team Size**: 1 developer + AI agent
- **Beta Testers**: 2 planned (wife and friend)

### Session Metrics

- **Debug Mode**: ~2 minutes total (7 sessions × 16-17 seconds)
- **Release Mode**: 20 minutes total (300+60+300+60+300+120+60 seconds)
- **Audio Duration**: ~40 seconds total (all instructions + gong)
- **Silent Practice**: ~19 minutes of actual breathing time

