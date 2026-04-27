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
}
```

Sessions defined as compile-time constants in `timer_screen.dart`, different
for debug vs. release builds. `audioDurationMs` was removed when the
fire-and-forget `_play` pattern was introduced — the loop no longer needs
to subtract audio duration from the delay.

## Audio Playback Pattern

### Play Helper

```dart
Future<void> _play(String audioPath) async
```

Responsibilities:

1. **Stop previous playback**: Ensures clean state
2. **Start new playback**: Fire-and-forget — does not wait for completion

`_runExerciseSequence` is the director of all timing. `_play` is a thin
wrapper that stops and starts the player. Waiting (for audio duration or
silence) is handled by `Future.delayed` in the calling loop.

**Design decision**: fire-and-forget over stream-based completion. The
original `_playAudioAndWait` waited for `onPlayerComplete` via a
`Completer`. Removed because audio durations are known constants and the
stream dependency made widget tests require `StreamController` stubs.
The trade-off (millisecond-level drift if `play()` has a driver delay)
is acceptable for a breathing exercise app.

### Audio Timing Coordination

Sessions execute sequentially:

```text
Session Start
  → _play(instructionAudio)
  → Future.delayed(durationMs − kGongDurationMs)
  → _play(gong)
  → Future.delayed(kGongDurationMs)
  → Next Session
```

The pre-gong delay covers both instruction audio playback and the silent
practice period. Instruction audio plays in the background during this
delay — no sequential wait required.

Total session time =
`(durationMs − kGongDurationMs) + kGongDurationMs` = `durationMs` ✓

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

## TimerEvent Model

All event types consolidated in `lib/timer_events.dart`:

```text
sealed class TimerEvent (lib/timer_events.dart)
  ├── ExerciseFinishedEvent
  │     offsetMs: total duration of all sessions
  └── PlaybackRequestedEvent
        offsetMs: when to play (ms from exercise start)
        audioFile: path to audio asset
```

`sealed` enables Dart 3 exhaustiveness checking on switch dispatchers.
All subtypes must live in same library — enforced by consolidation.

`TimerSchedule(List<SessionData>).buildEvents()` returns
`List<TimerEvent>` — pure calculation, no side effects, fully unit-tested.

**Internal helpers** (all stateless, return values):

- `produceOptionalSessionStartPlaybackEvent` →
  `List<PlaybackRequestedEvent>` (empty if no audio)
- `produceSessionEndPlaybackEvent` → `PlaybackRequestedEvent` (gong)
- `produceExerciseFinishedEvent` → `ExerciseFinishedEvent`

**Design decision**: optional events return `List<T>` (not `T?`) so
the call site can use `addAll` — cleaner than a null check + `add`.

**Equatable** used for value equality. Dispatch with `event is SubType`
(type promotion) not explicit cast. `ExerciseFinishedEvent` triggers
cleanup inline — no post-loop code needed.

## Event-Driven Execution Pattern

`_runExerciseSequence()` iterates events with delta-based delays:

```dart
var previousOffsetMs = 0;
for (final event in TimerSchedule(_sessions).buildEvents()) {
  final delayMs = event.offsetMs - previousOffsetMs;
  await Future.delayed(Duration(milliseconds: delayMs));
  if (event is PlaybackRequestedEvent) await _play(event.audioFile);
  if (event is ExerciseFinishedEvent) { /* cleanup + setState */ }
  previousOffsetMs = event.offsetMs;  // ← must update every iteration
}
```

**Critical**: `previousOffsetMs` must update every iteration. Forgetting
causes each delay to use absolute offset → sequence takes ~8× too long.

## Widget Test Patterns

### Fixture Setup

```dart
late MockAudioPlayer player;

setUpAll(() {
  registerFallbackValue(AssetSource('')); // required for any() on Source params
});

setUp(() {
  player = MockAudioPlayer();
  when(() => player.dispose()).thenAnswer((_) async {});
  when(() => player.stop()).thenAnswer((_) async {});
  when(() => player.play(any())).thenAnswer((_) async {});
});
```

`setUpAll` before `setUp` by convention. `registerFallbackValue` must be in
`setUpAll` — `when(...any()...)` is evaluated before test body runs.
`late` gives fresh `MockAudioPlayer` per test with identical isolation to
local declaration.

### Asserting Audio Calls

`AssetSource` does not implement `==`/`hashCode`. Use `captureAny()` via a
local helper that closes over `player`:

```dart
void expectPlayerReceivedInOrder(List<String> audioFilePaths) {
  final captured = verify(() => player.play(captureAny())).captured;
  expect(captured.length, equals(audioFilePaths.length));
  for (var i = 0; i < audioFilePaths.length; i++) {
    expect(captured[i], isA<AssetSource>().having((a) => a.path, 'path', audioFilePaths[i]));
  }
}
```

`verify` consumes interactions — call once after advancing to the last
expected play, capturing all in order.

### Timing in Widget Tests

`testWidgets` uses fake-async. `tester.pump(duration)` processes tap effects
(t=0) AND all timers up to `duration` in one call — no separate zero-duration
pump needed before a timed pump.

```dart
// Tap then advance to gong (14,330ms into first session):
await tester.tap(find.text('Start'));
await tester.pump(const Duration(milliseconds: gongPlaybackStartMs));
// Both instruction audio (t=0) and gong (t=14330ms) captured here.
```

#### Timing constants (debug mode)

```dart
const kSessionDurationMs = 20_000;   // first session debug duration
const kExerciseDurationMs = 140_000; // full 7-session sequence
// gong fires at:
const gongPlaybackStartMs = kSessionDurationMs - kGongDurationMs; // 14_330
```

#### Draining pending timers (mandatory)

```dart
await tester.pump(const Duration(milliseconds: kExerciseDurationMs));
```

Failing to drain → `'!timersPending'` assertion failure.

#### Test redundancy rule

Widget tests verify wiring (correct audio file, correct state). Timing
correctness (offsetMs values) belongs in `timer_schedule_test.dart` unit
tests — do not duplicate in widget tests.

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
