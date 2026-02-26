class LevelLoadingState {
  const LevelLoadingState({
    required this.isVisible,
    required this.progress,
    required this.message,
  });

  const LevelLoadingState.hidden()
    : isVisible = false,
      progress = 0,
      message = '';

  final bool isVisible;
  final double progress;
  final String message;
}
