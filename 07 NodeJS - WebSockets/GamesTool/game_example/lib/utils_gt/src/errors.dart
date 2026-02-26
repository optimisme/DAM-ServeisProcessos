class GamesToolProjectException implements Exception {
  GamesToolProjectException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'GamesToolProjectException: $message';
    }
    return 'GamesToolProjectException: $message (cause: $cause)';
  }
}

class GamesToolProjectFormatException extends GamesToolProjectException {
  GamesToolProjectFormatException(super.message, {super.cause});
}

class GamesToolProjectAssetNotFoundException extends GamesToolProjectException {
  GamesToolProjectAssetNotFoundException(super.message, {super.cause});
}
