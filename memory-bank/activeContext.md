# Active Context

## Current Iteration Goal

### Fix screen lock issue to enable automatic display sleep mode

Implement notification-based timing approach (documented in ADR-001) so users
can complete the 20-minute breathing exercise sequence with their device's
automatic display sleep enabled.

## Current Focus

### Step 6: Foundation Setup ⏳ Next

Add `flutter_local_notifications` + `timezone` to `pubspec.yaml`, configure
iOS `Info.plist` and Android `AndroidManifest.xml`, initialize plugin in
`main()`. No behavior change — additive only.

Expected commit: `build(deps): add flutter_local_notifications for background timing`

**Step 5 completed (commits b546a64, 575807f):**

- ✅ `_runExerciseSequence()` iterates `TimerSchedule(_sessions).buildEvents()`
  — delta-based delays: `delayMs = event.offsetMs - previousOffsetMs`
- ✅ `PlaybackRequestedEvent` dispatched via `event is PlaybackRequestedEvent`
  (type promotion, no cast)
- ✅ `ExerciseFinishedEvent` triggers cleanup inline (cancel progress timer,
  setState idle) — no post-loop cleanup needed
- ✅ `TimerEvent` hierarchy consolidated: `timer_event.dart`,
  `playback_requested_event.dart`, `exercise_finished_event.dart` → single
  `lib/timer_events.dart` with `sealed class TimerEvent`
- ✅ Dart 3 exhaustiveness checking now active on all switch dispatchers

**Key bug caught in Step 5:** `previousOffsetMs` not updated in loop →
each delay used absolute offset not delta → sequence took ~8× longer than
140s. Fix: `previousOffsetMs = event.offsetMs` at end of each iteration.

### Up next after Step 6: Notification-based background timing

Replacing `Future.delayed()` timer approach with OS-native scheduled
notifications to maintain accurate timing when screen locks.

**Previous Achievement**: Audio volume increased and deployed as v1.0.0+2.
All 4 German voice instruction audio files were re-exported at higher volume.
Deployed to TestFlight.

**Previous Achievement**: TestFlight deployment completed successfully.
All 8 steps completed:

- ✅ App Store Connect record created
- ✅ Distribution certificate configured
- ✅ Xcode project signing set up
- ✅ Build and archive created (with CocoaPods fix)
- ✅ MinimumOSVersion validation issue resolved
- ✅ Archive uploaded to TestFlight
- ✅ Apple build processing completed
- ✅ Beta testers invited

**Full deployment process documented in**: `docs/appstore-submission-de-DE/README.md`

### Current iOS Configuration

- Bundle identifier: `systems.boos.multiTimer` (registered in Apple Developer portal)
- App Store Connect name: "Multi Timer für Atempraxis"
- Local display name: "Multi Timer" (in Info.plist)
- Version: 1.0.0+2 (current TestFlight build)
- App icons: Complete set including 1024x1024 for App Store
- Git tag: v4 (tracks build 1.0.0+1; build 1.0.0+2 not separately tagged)

## Recent Changes

### Beta Feedback Received

#### Priority 1: Screen Lock Issue

- Beta testers reported that the screen lock limitation is their most urgent need
- They wish the app would work while automatic display sleep mode is enabled
- **Impact**:
  - Users must manually disable auto-lock in Settings before each practice session
  - Users must remember to re-enable auto-lock after practice
  - **Security risk**: Forgetting to re-enable leaves device unprotected
  - Creates friction and cognitive burden (pre/post practice routine)
- **Decision**: Implement notification-based approach from ADR-001

#### Priority 2: Audio Volume ✅ Resolved in v1.0.0+2

- Beta tester suggested increasing the volume of the audio instructions
- **Impact**: Refinement - app was usable but audio could be clearer
- **Solution**: Re-exported all 4 German voice instruction audio files at
  higher volume
- **Released**: v1.0.0+2 deployed to TestFlight (build: Jan 17, 2026)

**Prioritization Rationale**: Screen lock issue creates security risk (users may
forget to re-enable auto-lock) and adds friction to every practice session.
Audio volume is an enhancement that can be addressed in a subsequent release.

### Previous Development

The git history shows steady development of the core breathing timer
functionality:

- Latest feature: Added "Nachspüren" (sensing/feeling) session to complete
  the 7-session sequence
- Recent fixes: Audio playback reliability improvements
- Progress indicator: Visual feedback during exercise sequence
- Audio integration: German-language exercise instructions play before each session
- Debug mode: Shortened timings (16-17 seconds) for rapid development testing

## Active Decisions

### Confirmed by Beta Feedback

- ✅ Screen lock fix is the #1 priority (beta testers' most urgent need)
- ✅ Proceeding with notification-based approach from ADR-001

### Accepted Architecture Decisions

- ✅ ADR-001: Accepted — `flutter_local_notifications` chosen for
  background timer reliability
- ✅ ADR-002: Accepted — three-layer testing strategy
  (unit, widget, manual) chosen for notification refactoring

### Current Implementation Approach

- **Single increment delivery**: 16 independently testable and
  committable steps
- **Steps 1-2**: ✅ Complete — TimerSchedule extraction and cleanup
- **Step 3**: ✅ Complete — AudioPlayer injectable, widget test infrastructure
- **Step 4**: ✅ Complete — Widget tests for `_runExerciseSequence()` (commit 652a03d)
- **Step 5**: ✅ Complete — Event-driven loop + sealed TimerEvent (commits b546a64, 575807f)
- **Step 6**: ⏳ Foundation Setup — add flutter_local_notifications
- **Steps 6-12**: Additive notification infrastructure and validation
  (don't break existing functionality)
- **Step 13**: Transformation (replace timer with notifications)
- **Steps 14-16**: Refinement and edge case handling

### Still Pending Beta Feedback

- Future product direction (private vs. public release)
- Additional features or breathing programs
- Timing customization needs

## Important Patterns

### Debug vs. Release Mode

The app uses Flutter's `kDebugMode` to switch between:

- **Debug**: 16-17 second sessions for quick testing
- **Release**: Full duration (300-60-300-60-300-120-60 seconds = 20 minutes total)

This pattern allows rapid iteration without waiting through 20-minute sequences.

### Audio File Organization

```text
assets/
  - gong.mp3 (session end marker)
  - release/
    - ganzkoerperatmung.mp3 (full body breathing, ~8s)
    - atem-halten.mp3 (breath holding, ~8.7s)
    - wellenatmen.mp3 (wave breathing, ~9s)
    - nachspueren.mp3 (sensing, ~5.6s)
  - debug/ (not currently used in code)
```

German-language recordings provide exercise instructions before each timed session.

### Session Timing Architecture

Each session duration accounts for:

1. Audio instruction duration (pre-session)
2. Silent practice time (bulk of session)
3. Gong sound duration (6080ms, end of session)

The code subtracts audio and gong durations from total session time to achieve
precise timing.

## Next Immediate Steps

**Step 6 — Foundation Setup:**

Add notification infrastructure without changing app behavior:

- Add `flutter_local_notifications` and `timezone` to `pubspec.yaml`
- Configure iOS (`Info.plist` — notification permissions)
- Configure Android (`AndroidManifest.xml`)
- Initialize notification plugin in `main()`

Run `flutter test` after to confirm no regressions.
Expected commit: `build(deps): add flutter_local_notifications for background timing`

## Blockers

None identified. Prerequisites met:

- ✅ Paid Apple Developer account
- ✅ macOS with Xcode available
- ✅ Initial beta feedback received from both testers
- ✅ Technical solution documented (ADR-001)
- ✅ Implementation plan defined

## Project Insights

### Lean Approach

The project follows lean principles:

- MVP focused on single use case
- Small beta group for fast feedback
- Accepted known limitation to ship faster
- Clear decision point based on real usage data

### Development in Sandbox

Development occurs in a Linux VM to protect the host Mac from AI agent
operations. Changes sync to Mac for iOS building via rsync with filters for
.git, .gitignore, and .rsyncignore files.

### Shamanic and Yoga Practice Context

This is not a general-purpose timer app. It serves a specific breathing
exercise rooted in self-healing principles from shamanic and yoga traditions.
The fixed sequence and German audio instructions are intentional and core to
this practice.
