import 'package:multi_timer/main.dart';
import 'package:multi_timer/timer_event.dart';
import 'package:test/test.dart';
import 'package:multi_timer/timer_schedule.dart';
import 'package:multi_timer/exercise_finished_event.dart';
import 'package:multi_timer/playback_requested_event.dart';

void expectSingleExerciseFinishedEventWithOffset(List<TimerEvent> actualEvents, int expectedOffsetMs) {
  final actualExerciseFinishedEvents = actualEvents.whereType<ExerciseFinishedEvent>();
  expect(actualExerciseFinishedEvents, hasLength(1));
  final actualExerciseFinishedEvent = actualExerciseFinishedEvents.first;
  expect(actualExerciseFinishedEvent.offsetMs, expectedOffsetMs);
}

void expectPlaybackRequestedEventForAudio(PlaybackRequestedEvent event, int expectedOffsetMs, String expectedAudioFile) {
  expect(event.offsetMs, expectedOffsetMs);
  expect(event.audioFile, expectedAudioFile);
}

void expectPlaybackRequestedEventForGongAudio(PlaybackRequestedEvent lastEvent, int sessionDurationMs) {
  
  // The gongAudioDurationMs is reflected by the constant kGongDurationMs in main.dart.
  // The gongAudioFile is reflected by the constant kGongAudioFile in main.dart.
  //
  // In a test we look from the perspective of the product owner, who only knows the
  // file and the duration, but not the implementation details that these properties are
  // as a constants in the code. So we use the "magic values" here.

  final gongAudioDurationMs = 6080;
  final gongAudioFile = 'gong.mp3';
  expect(lastEvent.offsetMs, sessionDurationMs - gongAudioDurationMs);
  expect(lastEvent.audioFile, gongAudioFile);
}

void main() {
  group('TimerSchedule shall calculate ExerciseFinishedEvent offsets:', () {
    test('When no sessions, then ExerciseFinishedEvent offset is 0', () {
      final schedule = TimerSchedule([]);

      final actualEvents = schedule.buildEvents();

      final expectedExerciseDurationMs = 0;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });
    
    test('When a single session, then ExerciseFinishedEvent offset is session duration', () {
      final sessionDurationMs = 1_000_000;
      final arbitraryDurationMs = 123;
      final schedule = TimerSchedule([SessionData(sessionDurationMs, null, arbitraryDurationMs)]);

      final actualEvents = schedule.buildEvents();

      final expectedExerciseDurationMs = sessionDurationMs;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });

    test('When three sessions, then ExerciseFinishedEvent offset is sum of session durations', () {
      final sessionDurationMs = 1000;
      final arbitraryDurationMs = 123;
      final schedule = TimerSchedule([
        SessionData(sessionDurationMs, null, arbitraryDurationMs),
        SessionData(sessionDurationMs, null, arbitraryDurationMs),
        SessionData(sessionDurationMs, null, arbitraryDurationMs),
      ]);

      final actualEvents = schedule.buildEvents();
      final expectedExerciseDurationMs = 3 * sessionDurationMs;
      expectSingleExerciseFinishedEventWithOffset(actualEvents, expectedExerciseDurationMs);
    });
  });

  group('TimerSchedule.buildEvents shall calculate PlaybackRequestedEvents:', () {
    test('When no sessions, then return no PlaybackRequestedEvent', () {
      final schedule = TimerSchedule([]);

      final actualEvents = schedule.buildEvents();

      final actualPlaybackRequestedEvents = actualEvents.whereType<PlaybackRequestedEvent>();
      expect(actualPlaybackRequestedEvents, isEmpty);
    });
 
    test('When a single session, then return two PlaybackRequestedEvents', () {
      final sessionDurationMs = 15_000;
      final sessionAudioFile = 'session_audio.mp3';
      final sessionAudioDurationMs = 3000;
      final schedule = TimerSchedule([SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs)]);

      final actualEvents = schedule.buildEvents();

      final actualPlaybackRequestedEvents = actualEvents.whereType<PlaybackRequestedEvent>();
      expect(actualPlaybackRequestedEvents, hasLength(2));

      expectPlaybackRequestedEventForAudio(actualPlaybackRequestedEvents.first, 0, sessionAudioFile);
      expectPlaybackRequestedEventForGongAudio(actualPlaybackRequestedEvents.last, sessionDurationMs);
    });

    test('When a single session and no session audio file, then return single PlaybackRequestedEvent', () {
      final sessionDurationMs = 15_000;
      final sessionAudioFile = null;
      final sessionAudioDurationMs = 0;
      final schedule = TimerSchedule([SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs)]);

      final actualEvents = schedule.buildEvents();

      final actualPlaybackRequestedEvents = actualEvents.whereType<PlaybackRequestedEvent>();
      expect(actualPlaybackRequestedEvents, hasLength(1));

      expectPlaybackRequestedEventForGongAudio(actualPlaybackRequestedEvents.last, sessionDurationMs);
    });

    test('When two sessions, then second session audio has correct offset', () {
      final sessionDurationMs = 15_000;
      final sessionAudioFile = 'session_audio.mp3';
      final sessionAudioDurationMs = 3000;
      final schedule = TimerSchedule([
        SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs),
        SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs),
      ]);

      final actualEvents = schedule.buildEvents();

      final actualPlaybackRequestedEvents = actualEvents.whereType<PlaybackRequestedEvent>();
      expect(actualPlaybackRequestedEvents, hasLength(4));

      expectPlaybackRequestedEventForAudio(actualPlaybackRequestedEvents.elementAt(2), sessionDurationMs, sessionAudioFile);
    });

    test('When two sessions, then final gong has correct offset', () {
      final sessionDurationMs = 15_000;
      final sessionAudioFile = 'session_audio.mp3';
      final sessionAudioDurationMs = 3000;
      final schedule = TimerSchedule([
        SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs),
        SessionData(sessionDurationMs, sessionAudioFile, sessionAudioDurationMs),
      ]);

      final actualEvents = schedule.buildEvents();

      final actualPlaybackRequestedEvents = actualEvents.whereType<PlaybackRequestedEvent>();
      expect(actualPlaybackRequestedEvents, hasLength(4));

      expectPlaybackRequestedEventForGongAudio(actualPlaybackRequestedEvents.last, sessionDurationMs * 2);
    });
  });
}
