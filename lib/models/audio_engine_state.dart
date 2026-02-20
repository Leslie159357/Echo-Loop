class AudioEngineState {
  final Duration clipStart;
  final Duration? totalDuration;
  final bool isLoading;
  final int sessionId;
  final String? currentAudioId;
  final String? errorMessage;

  const AudioEngineState({
    this.clipStart = Duration.zero,
    this.totalDuration,
    this.isLoading = false,
    this.sessionId = 0,
    this.currentAudioId,
    this.errorMessage,
  });

  AudioEngineState copyWith({
    Duration? clipStart,
    Duration? totalDuration,
    bool? isLoading,
    int? sessionId,
    String? currentAudioId,
    String? errorMessage,
  }) {
    return AudioEngineState(
      clipStart: clipStart ?? this.clipStart,
      totalDuration: totalDuration ?? this.totalDuration,
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      currentAudioId: currentAudioId ?? this.currentAudioId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
