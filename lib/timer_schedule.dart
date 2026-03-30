import 'package:multi_timer/constants.dart';
import 'package:multi_timer/playback_requested_event.dart';
import 'package:multi_timer/session_data.dart';
import 'package:multi_timer/timer_event.dart';
import 'exercise_finished_event.dart';

class TimerSchedule {
  final List<SessionData> sessions;
  
  TimerSchedule(this.sessions);

  List<TimerEvent> buildEvents() {
    final List<TimerEvent> result = [];
    var sessionStartOffsetMs = 0;
        
    for (var session in sessions) {
      result.addAll(produceOptionalSessionStartPlaybackEvent(session, sessionStartOffsetMs));
      result.add(produceSessionEndPlaybackEvent(session, sessionStartOffsetMs));
      sessionStartOffsetMs += session.durationMs;
    }

    result.add(produceExerciseFinishedEvent(sessionStartOffsetMs));
    return result;
  }

  List<PlaybackRequestedEvent> produceOptionalSessionStartPlaybackEvent(SessionData session, int sessionStartOffsetMs) {
    final List<PlaybackRequestedEvent> result = [];

    final audioFile = session.audioFile;
    if (audioFile != null) {
      final sessionStartPlaybackRequestedEvent = PlaybackRequestedEvent(offsetMs: sessionStartOffsetMs, audioFile: audioFile);
      result.add(sessionStartPlaybackRequestedEvent);
    }

    return result;
  }

  PlaybackRequestedEvent produceSessionEndPlaybackEvent(SessionData session, int sessionStartOffsetMs) {
    var gongOffsetMs = sessionStartOffsetMs + session.durationMs - kGongDurationMs;
    return PlaybackRequestedEvent(offsetMs: gongOffsetMs, audioFile: kGongAudioFile);
  }

  ExerciseFinishedEvent produceExerciseFinishedEvent(int exerciseDurationMs) {
    return ExerciseFinishedEvent(offsetMs: exerciseDurationMs);
  }
}
