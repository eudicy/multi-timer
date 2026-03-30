# Test Strategy — Multi Timer

## Decision Context

This document is the **how** — concrete implementation guidance
for the testing strategy.

- **ADR-002** is the **why** — the decision rationale and option
  comparison that led to the three-layer approach documented here.
- **ADR-001** documents the architectural change (notification-
  based timer) that this testing strategy is designed to support.

---

## Overview

Multi Timer plays a fixed sequence of guided-audio sessions followed by a gong.
Its testable behaviour falls into three areas:

1. **Logic** — timing arithmetic and session scheduling (fully automatable)
2. **UI state** — which screen is shown and when (automatable with fakes)
3. **Background execution** — continuing correctly when the screen locks
   (requires code changes + manual testing on real devices)

---

## 1. Unit Tests

### Unit test scope

Pure Dart logic with no Flutter framework or hardware dependency.

| Subject                     | What to verify                                                       |
| --------------------------- | -------------------------------------------------------------------- |
| `SessionData`               | `audioDurationMs` defaults to `0`; other fields assigned correctly   |
| Total duration              | Sum of all `session.durationSeconds * 1000`                          |
| Per-session remaining delay | `durationSeconds * 1000 − kGongDurationMs − audioDurationMs`         |
| Playback schedule           | Each event has the correct `audioFile` and `offsetMs` from t=0       |
| Progress                    | `elapsed / totalDuration` clamped to `[0.0, 1.0]`                   |

### Refactoring: extract TimerSchedule

All timing logic currently lives inside `_TimerScreenState`. It must be
extracted into a plain Dart class before unit tests can be written.

This extraction serves a dual purpose:

1. **Testability** — `TimerSchedule` is a pure Dart class with no
   Flutter or hardware dependency; it can be unit-tested directly.
2. **Notification scheduling** — the `offsetMs` values produced by
   `buildEvents()` for gong events are the notification fire times
   used by `flutter_local_notifications` (ADR-001). In the
   notification-based implementation the gong sound is delivered by
   the OS notification at the session boundary, so the fire time
   equals the cumulative session boundary (not boundary minus
   `kGongDurationMs` as in the current in-app approach).
Suggested structure:

```dart
// lib/timer_schedule.dart

class PlaybackEvent {
  final String audioFile;
  final int offsetMs; // milliseconds from timer start
  const PlaybackEvent(this.audioFile, this.offsetMs);
}

class TimerSchedule {
  final List<SessionData> sessions;
  TimerSchedule(this.sessions);

  int get totalDurationMs =>
      sessions.fold(0, (sum, s) => sum + s.durationSeconds * 1000);

  List<PlaybackEvent> buildEvents() {
    final events = <PlaybackEvent>[];
    int cursor = 0;
    for (final session in sessions) {
      if (session.audioFile != null) {
        events.add(PlaybackEvent(session.audioFile!, cursor));
        cursor += session.audioDurationMs;
      }
      cursor += session.durationSeconds * 1000
          - kGongDurationMs
          - (session.audioFile != null ? session.audioDurationMs : 0);
      events.add(PlaybackEvent('gong.mp3', cursor));
      cursor += kGongDurationMs;
    }
    return events;
  }
}
```

### Example tests

```dart
// test/unit/timer_schedule_test.dart

void main() {
  group('TimerSchedule', () {
    test('totalDurationMs sums all sessions', () {
      final schedule = TimerSchedule([
        SessionData(300_000, 'a.mp3', 8000),
        SessionData(60_000),
      ]);
      expect(schedule.totalDurationMs, equals(360 * 1000));
    });

    test('gong is the last event of a session with no audio', () {
      final schedule = TimerSchedule([SessionData(60_000)]);
      final events = schedule.buildEvents();
      expect(events.last.audioFile, equals('gong.mp3'));
      // gong starts at: 60000 - kGongDurationMs
      expect(events.last.offsetMs, equals(60000 - kGongDurationMs));
    });

    test('guided audio fires before the gong in the same session', () {
      final schedule = TimerSchedule([
        SessionData(300_000, 'breathing.mp3', 8000),
      ]);
      final events = schedule.buildEvents();
      expect(events[0].audioFile, equals('breathing.mp3'));
      expect(events[0].offsetMs, equals(0));
      expect(events[1].audioFile, equals('gong.mp3'));
      expect(events[1].offsetMs, greaterThan(events[0].offsetMs));
    });
  });
}
```

### Notification schedule verification

`buildEvents()` can be used to verify the notification fire times
computed for `flutter_local_notifications`. The expected release-
mode boundary times (cumulative seconds from t = 0) are:

| Session | Boundary (s) | Expected notification time |
| ------- | ------------ | -------------------------- |
| 1       | 300          | t = 300 000 ms             |
| 2       | 360          | t = 360 000 ms             |
| 3       | 660          | t = 660 000 ms             |
| 4       | 720          | t = 720 000 ms             |
| 5       | 1020         | t = 1 020 000 ms           |
| 6       | 1140         | t = 1 140 000 ms           |
| 7       | 1200         | t = 1 200 000 ms           |

Example test (verifies gong offsets for all 7 release sessions):

```dart
test('gong events fire at session boundaries', () {
  final schedule = TimerSchedule(releaseSessions);
  final gongs = schedule
      .buildEvents()
      .where((e) => e.audioFile == 'gong.mp3')
      .toList();
  expect(gongs.map((e) => e.offsetMs), equals([
    300000, 360000, 660000, 720000, 1020000, 1140000, 1200000,
  ]));
});
```

Note: in the current in-app implementation the gong *starts*
`kGongDurationMs` (6 080 ms) before the boundary so it *finishes*
at the boundary. In the notification-based approach the OS fires
the notification at the boundary and plays the gong from that
point. `buildEvents()` will need to be updated to reflect this
when the notification implementation is added.

### Unit test tools

- `test` package — already in `pubspec.yaml`
- No additional dependencies required for unit tests

**Reference examples:**

- [Kazumi — `test/m3u8_parser_test.dart`](https://github.com/Predidit/Kazumi/blob/main/test/m3u8_parser_test.dart):
  a real-world example of the same pattern — a parsing/calculation class
  extracted from app logic and tested as pure Dart, no Flutter dependency.
- [localsend — `app/test/unit/`](https://github.com/localsend/localsend/tree/main/app/test/unit):
  a focused unit test suite at comparable project scale, showing how to
  organise mocks alongside unit tests.

### Run unit tests

```bash
flutter test test/unit/
```

---

## 2. Widget Tests

### Widget test scope

Flutter UI state — which screen is rendered under which conditions.

| Scenario          | What to verify                                              |
| ----------------- | ----------------------------------------------------------- |
| Initial state     | `AppBar` with "Multi Timer" and a "Start" button visible    |
| Counting state    | Black `Scaffold`, no `AppBar`, progress bar container visible |
| After completion  | Returns to initial state; "Start" button visible again      |

### Refactoring: inject AudioPlayer

`_TimerScreenState` constructs `AudioPlayer` directly. The player must be
injectable so tests can supply a fake:

```dart
class _TimerScreenState extends State<TimerScreen> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = widget.audioPlayer ?? AudioPlayer();
  }
}

class TimerScreen extends StatefulWidget {
  final AudioPlayer? audioPlayer; // nullable; real app passes null
  const TimerScreen({super.key, this.audioPlayer});
  ...
}
```

### Faking time with `fake_async`

`_startTimer()` uses `Timer.periodic` and `Future.delayed`. In a widget test
these would make the test hang waiting for real time. `fake_async` replaces
the clock so you can advance time instantly:

```dart
// test/widget/timer_screen_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  testWidgets('shows Start button initially', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TimerScreen(audioPlayer: MockAudioPlayer())),
    );
    expect(find.text('Start'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('switches to counting screen after Start', (tester) async {
    fakeAsync((async) {
      final mock = MockAudioPlayer();
      // Make play() complete immediately and fire onPlayerComplete
      when(() => mock.play(any())).thenAnswer((_) async {
        mock.onPlayerComplete.add(null);
      });
      when(() => mock.stop()).thenAnswer((_) async {});

      tester.pumpWidget(MaterialApp(home: TimerScreen(audioPlayer: mock)));
      tester.tap(find.text('Start'));
      async.elapse(Duration.zero); // flush microtasks
      tester.pump();

      expect(find.byType(AppBar), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        equals(Colors.black),
      );
    });
  });
}
```

**Important:** `fake_async` controls `Timer` and `Future.delayed`, but it does
**not** control `audioplayers` streams. This is why the mock must manually fire
`onPlayerComplete` — otherwise `_playAudioAndWait()` will never resolve and the
test will hang even with `fakeAsync`.

### Widget test tools and dependencies

```yaml
# pubspec.yaml — dev_dependencies
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.29.0           # already present
  fake_async: ^1.3.2      # ADD: controls Timer / Future.delayed in tests
  mocktail: ^1.0.4        # ADD: mock AudioPlayer without code generation
```

Use **`mocktail`** rather than `mockito`. `mocktail` does not require the
`build_runner` code-generation step, which keeps the test setup simpler.

**Reference examples:**

- [AppFlowy — `frontend/appflowy_flutter/test/`](https://github.com/AppFlowy-IO/AppFlowy/tree/main/frontend/appflowy_flutter/test):
  a well-organised example using `mocktail` and `flutter_test` with the same
  `unit_test/`, `widget_test/` folder structure recommended here.
- [Flutter framework — `packages/flutter/test/`](https://github.com/flutter/flutter/tree/main/packages/flutter/test):
  the authoritative reference for `fake_async` usage patterns; see any file
  under `test/widgets/` or `test/material/` for examples of combining
  `fakeAsync` with `tester.pump()`.

### Run widget tests

```bash
flutter test test/widget/
```

---

## 3. Manual Tests — Screen Lock & Background Execution

### Why this cannot be automated

The automated layers above run entirely inside Dart's event loop. They cannot
simulate:

- **Android Doze mode** — the OS throttles or suspends `Timer` and
  `Future.delayed` when the screen is off and the app holds no wakelock
- **iOS background execution** — iOS suspends the app when the screen locks;
  the Dart isolate is paused and `Future.delayed()` timers stop counting
- **`AppLifecycleState.paused`** — the Flutter engine notifies the app when it
  moves to the background, but how the OS behaves after that depends on the
  platform and device manufacturer
- **Manufacturer-specific battery management** — Samsung, Xiaomi, Huawei and
  others apply aggressive background-kill policies on top of stock Android

Even emulators do not replicate OS power management. **Real devices are
required.**

### Implementation prerequisite

The background execution fix is an architectural decision documented in
**ADR-001: Background Timer Reliability with Screen Lock**. The manual tests
below are only meaningful once the chosen solution from that ADR has been fully
implemented on the target platform.

The observable behaviour under test — gong sounds and guided audio firing at
the correct times while the screen is locked — is the same regardless of which
implementation option is selected.

### Test protocol

Run this checklist on **at least one physical Android device and one physical
iOS device** before every release. Use a **release build** — debug mode uses
short session durations (16 s) which differ from release durations (60–300 s).

```bash
flutter run --release
```

**Session timing reference (release mode):**

| Session | Duration | Guided audio starts at | Gong plays at (approx.) |
| ------- | -------- | ---------------------- | ----------------------- |
| 1       | 300 s    | t = 0 s                | t ≈ 294 s               |
| 2       | 60 s     | t ≈ 300 s              | t ≈ 354 s               |
| 3       | 300 s    | t ≈ 360 s              | t ≈ 654 s               |
| 4       | 60 s     | t ≈ 660 s              | t ≈ 714 s               |
| 5       | 300 s    | t ≈ 720 s              | t ≈ 1014 s              |
| 6       | 120 s    | t ≈ 1020 s             | t ≈ 1131 s              |
| 7       | 60 s     | t ≈ 1140 s             | t ≈ 1194 s              |

*(The gong fires ~6 s before the session boundary because its 6080 ms duration
is subtracted from the delay — the gong finishes exactly at the boundary.)*

**Checklist:**

```text
Setup
  [ ] Install a release build on the test device
  [ ] Set the device's auto-lock / screen timeout to 30 seconds
  [ ] Disable any "do not disturb" or silent-mode settings
  [ ] Note the start time (or start a reference stopwatch)

Execution
  [ ] Open the app and tap Start
  [ ] Wait for the screen to lock automatically (within 30 s)
  [ ] Leave the phone locked and undisturbed for at least 5 minutes

Verification — background execution
  [ ] Guided audio plays at t ≈ 0 s (session 1 starts)
  [ ] Gong plays at t ≈ 294 s
  [ ] Guided audio plays at t ≈ 300 s (session 2 starts)
  [ ] Gong plays at t ≈ 354 s
  [ ] (Continue checking at each session boundary)

Verification — app state after unlocking
  [ ] Unlock the phone mid-timer: progress bar reflects correct progress
  [ ] App completes normally and returns to the Start screen
  [ ] No crash or ANR dialog on Android

Edge cases (run separately)
  [ ] Incoming phone call during timer: audio resumes after call ends
  [ ] Notification sound during timer: guided audio is not interrupted
  [ ] Plug / unplug headphones mid-timer: audio continues on the new output
```

---

## What Is Not Tested

| Area                        | Reason                                                               |
| --------------------------- | -------------------------------------------------------------------- |
| Golden / screenshot tests   | The UI is minimal and static; visual regression testing adds no value |
| `flutter_driver` E2E tests  | Overkill for a single-screen app; the manual checklist covers it     |
| Audio quality / volume      | Subjective and device-dependent; out of scope                        |

---

## Summary

| Layer                       | Automation       | Tools                                | Prerequisite                          |
| --------------------------- | ---------------- | ------------------------------------ | ------------------------------------- |
| Logic (timing, scheduling)  | Automated        | `test`                               | Extract `TimerSchedule` class         |
| UI state                    | Automated        | `flutter_test`, `fake_async`, `mocktail` | Inject `AudioPlayer`              |
| Screen lock / background    | Manual checklist | Real device, release build           | ADR-001 solution implemented          |
