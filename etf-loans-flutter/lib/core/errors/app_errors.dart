class AppError implements Exception {
  final String message;
  final String? prefix;

  AppError([this.message = 'Unknown error', this.prefix]);

  @override
  String toString() => prefix != null ? '$prefix: $message' : message;
}

class FetchDataError extends AppError {
  FetchDataError([String? message]) : super(message ?? 'Failed to load data');
}

class ServerException extends AppError {
  ServerException([String? message]) : super(message ?? 'Server error');
}

class InvalidSessionException extends ServerException {
  InvalidSessionException() : super('Session expired. Please sign in again.');
}

class TimeoutException extends AppError {
  TimeoutException([String? message]) : super(message ?? 'Request timed out');
}

class NetworkException extends AppError {
  NetworkException([String? message]) : super(message ?? 'No network connection');
}
