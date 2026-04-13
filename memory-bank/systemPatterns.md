# System Patterns

## Architecture Overview

Multi Timer is a single-screen Flutter application with a straightforward
state-driven UI and sequential async timer execution.

## Key Components

### TimerScreen (StatefulWidget)

Main and only screen, managing two states:

1. **Idle State**: Shows AppBar and "Start" button
2. **Counting State**: Shows black screen with progress indicator

### State Management

Simple local state using `setState()`:

- `_isCounting`: Boolean toggle between idle and counting states
- `_progress`: Double (0.0 to 1.0) for visual progress bar
- `_progressTimer`: Periodic timer for UI updates
- `_player`: getter on `_TimerScreenState` → `widget._player` (injected)

No complex state management needed for this single-flow application.

### AudioPlayer Injection Pattern

`AudioPlayer` is injected via non-nullable positional constructor parameter
on `TimerScreen`. `_TimerScreenState` accesses it via a getter — no
`initState` override needed:

```dart
class TimerScreen extends StatefulWidget {
  final AudioPlayer _player;
  const TimerScreen(this._player, {super.key});
  ...
}
class _TimerScreenState extends State<TimerScreen> {
  AudioPlayer get _player => widget._player;
  ...
}
```

Production: `TimerScreen(AudioPlayer())` in `MultiTimerApp.build`.
Tests: `TimerScreen(MockAudioPlayer())` — stub `dispose()` as
`when(() => mock.dispose()).thenAnswer((_) async {})`.

**Design decision**: non-nullable over nullable+fallback — makes
dependency mandatory and visible at every call site.

### Session Data Model

```dart
// lib/session_data.dart
class SessionData {
  final int durationMs;        // Total session duration (milliseconds)
  final String? audioFile;     // Optional instruction audio
  final int audioDurationMs;   // Audio file length
}
```

Sessions defined as compile-time constants in `main.dart`, different for
debug vs. release builds.
All `SessionData(...)` call sites pass milliseconds directly.

## Audio Playback Pattern

### Playback-and-Wait Helper

```dart
Future<void> _playAudioAndWait(String audioPath) async
```

Critical implementation details:

1. **Stop previous playback**: Ensures clean state
2. **Setup listener BEFORE playing**: Avoids race condition
3. **Use Completer pattern**: Converts event callback to Future
4. **Cleanup subscription**: Prevents memory leaks

This pattern emerged after fixing "some audios not played" issue (commit faed597).

### Audio Timing Coordination

Sessions execute sequentially:

```text
Session Start → [Optional Audio] → [Silent Delay] → [Gong] → Next Session
```

Total session time = instruction audio + silent delay + gong duration

The code precisely subtracts audio durations to maintain accurate overall timing.

## Timer Execution Pattern

### Main Timer Loop

```dart
Future<void> _runExerciseSequence() async {
  // 1. Enter counting state
  // 2. Start progress timer (visual updates every 500ms)
  // 3. For each session:
  //    - Play instruction audio (if present)
  //    - Wait for calculated silent duration
  //    - Play gong
  // 4. Cancel progress timer
  // 5. Return to idle state
}
```

### Progress Calculation

Progress updates independently of session execution:

- Tracks elapsed time from sequence start
- Updates progress bar every 500ms
- Ensures smooth visual feedback regardless of audio timing

This separation of concerns keeps visual progress accurate even if audio
playback has minor delays.

## UI Patterns

### Conditional Scaffold Structure

```dart
if (_isCounting) {
  return Scaffold(backgroundColor: black, body: progressBar);
} else {
  return Scaffold(appBar: AppBar, body: startButton);
}
```

Complete UI replacement rather than conditional widget visibility.

### Progress Bar Design

- Fills from bottom to top (Align.bottomCenter + FractionallySizedBox)
- Semi-transparent purple color over black background
- Subtle visibility during practice
- Provides time awareness without distraction

## Platform-Specific Patterns

### Debug Mode Toggle

Uses Flutter's `kDebugMode` constant for compile-time configuration switching:

- Automatically adjusts session durations
- No runtime configuration needed
- Same code structure for both modes

### Asset Organization

Organized by deployment mode:

- `assets/release/`: Production audio files (German instructions)
- `assets/debug/`: Reserved for test audio (not currently active)
- `assets/gong.mp3`: Shared across all modes

## Critical Implementation Paths

### Audio Playback Reliability

Fixed in commits fae8a9e and faed597:

- **Problem**: Some audio files wouldn't play
- **Root cause**: Race condition between play() call and listener setup
- **Solution**: Register onPlayerComplete listener BEFORE calling play()
- **Pattern**: Use Completer to await event-based completion

### Session Timing Accuracy

Evolved through commits 09d8815 and earlier:

- **Challenge**: Maintain accurate 20-minute total duration while playing
  variable-length audio
- **Solution**: Calculate remaining delay = session duration - audio
  duration - gong duration
- **Result**: Precise session timing regardless of audio file lengths

### Progress Bar Timing

Separate timer for UI updates:

- **Why**: Audio playback and delays can have small variations
- **Solution**: Calculate progress based on wall-clock elapsed time, not
  session state
- **Benefit**: Smooth, predictable progress bar advancement

## TimerEvent Model (New — Step 0)

A new event hierarchy has been introduced to decouple timing logic
from UI and audio execution:

```text
TimerEvent (abstract, lib/timer_event.dart)
  ├── ExerciseFinishedEvent (lib/exercise_finished_event.dart)
  │     offsetMs: total duration of all sessions
  └── PlaybackRequestedEvent (lib/playback_requested_event.dart)
        offsetMs: when to play (ms from exercise start)
        audioFile: path to audio asset

lib/session_data.dart  — SessionData (extracted from main.dart)
lib/constants.dart     — kGongDurationMs, kGongAudioFile (extracted from main.dart)
```

`TimerSchedule(List<SessionData>).buildEvents()` returns
`List<TimerEvent>` — a pure calculation with no side effects.
Testable without Flutter, audio, or timers.

**Internal helpers** (all stateless, return values):

- `produceOptionalSessionStartPlaybackEvent` →
  `List<PlaybackRequestedEvent>` (empty if no audio)
- `produceSessionEndPlaybackEvent` → `PlaybackRequestedEvent` (gong)
- `produceExerciseFinishedEvent` → `ExerciseFinishedEvent`

**Design decision**: optional events return `List<T>` (not `T?`) so
the call site can use `addAll` — cleaner than a null check + `add`.

**Equatable** is used for value equality on all event classes.
Pattern-match on event type using Dart 3 `switch` expressions.

## Component Relationships

```text
MultiTimerApp (MaterialApp)  [lib/main.dart]
  └── TimerScreen (StatefulWidget)  [lib/timer_screen.dart]
      ├── AudioPlayer (injected — real in prod, MockAudioPlayer in tests)
      ├── SessionData list (compile-time constant)
      ├── TimerSchedule (new — pure calculation)  [lib/timer_schedule.dart]
      │     └── List<TimerEvent> (PlaybackRequestedEvent, ExerciseFinishedEvent)
      ├── Progress timer (periodic 500ms)
      └── Session execution (sequential async — to be replaced by notifications)
```

Minimal dependency graph - appropriate for single-purpose application.

## Technical Constraints

### Screen Lock Limitation

**Current architecture limitation**: Timer uses `Future.delayed()` which
stops when app suspends.

- iOS/Android suspend apps when screen locks
- Dart timers pause when isolate is suspended
- Audio playback stops mid-session

**Solution documented in ADR-001**: Use OS-native notifications instead
of Dart timers.

**Decision**: Accepted (ADR-001). Implementing notification-based
approach with `flutter_local_notifications`.

### Flutter/Dart Version

- Dart SDK: >=3.0.0 <4.0.0
- Flutter SDK: >=3.0.0
- Uses Material 3 design
- Targets modern iOS and Android versions
