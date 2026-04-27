import 'package:equatable/equatable.dart';

sealed class TimerEvent extends Equatable {
  final int offsetMs;

  const TimerEvent({required this.offsetMs});

  @override
  List<Object?> get props => [offsetMs];
}

class ExerciseFinishedEvent extends TimerEvent {
  const ExerciseFinishedEvent({required super.offsetMs});
}

class PlaybackRequestedEvent extends TimerEvent {
  final String audioFile;

  const PlaybackRequestedEvent({
    required super.offsetMs,
    required this.audioFile,
  });

  @override
  List<Object?> get props => [offsetMs, audioFile];
}

