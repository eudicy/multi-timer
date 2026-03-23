import 'package:multi_timer/main.dart';
import 'package:test/test.dart';
import 'package:multi_timer/timer_schedule.dart';
import 'package:multi_timer/exercise_finished_event.dart';

void expectSingleExerciseFinishedEventWithOffset(List<ExerciseFinishedEvent> actualEvents, int expectedOffsetMs) {
  final actualExerciseFinishedEvents = actualEvents.whereType<ExerciseFinishedEvent>();
  expect(actualExerciseFinishedEvents, hasLength(1));
  final actualExerciseFinishedEvent = actualExerciseFinishedEvents.first;
  expect(actualExerciseFinishedEvent.offsetMs, expectedOffsetMs);
}

void main() {
  group('TimerSchedule', () {
    test('when no sessions, then ExerciseFinishedEvent offset is 0', () {
      final schedule = TimerSchedule([]);

      final actualEvents = schedule.buildEvents();

      final expectedExerciseDurationMs = 0;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });
    
    test('when a single session, then ExerciseFinishedEvent offset is session duration', () {
      final sessionDurationSeconds = 1000;
      final arbitraryDurationMs = 123;
      final schedule = TimerSchedule([SessionData(sessionDurationSeconds, null, arbitraryDurationMs)]);

      final actualEvents = schedule.buildEvents();

      final expectedExerciseDurationMs = sessionDurationSeconds * 1000;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });

    test('when three sessions, then ExerciseFinishedEvent offset is sum of session durations', () {
      final sessionDurationSeconds = 1;
      final arbitraryDurationMs = 123;
      final schedule = TimerSchedule([
        SessionData(sessionDurationSeconds, null, arbitraryDurationMs),
        SessionData(sessionDurationSeconds, null, arbitraryDurationMs),
        SessionData(sessionDurationSeconds, null, arbitraryDurationMs),
      ]);

      final actualEvents = schedule.buildEvents();
      final expectedExerciseDurationMs = 3 * sessionDurationSeconds * 1000;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });
  });
}
