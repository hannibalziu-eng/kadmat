import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Server error occurred'});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error occurred'});
}

class ValidationFailure extends Failure {
  const ValidationFailure({super.message = 'Invalid input'});
}

class RateLimitFailure extends Failure {
  final DateTime? retryAfter;

  const RateLimitFailure({
    super.message = 'Rate limit exceeded',
    this.retryAfter,
  });

  @override
  List<Object?> get props => [message, retryAfter];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Unauthorized access'});
}

class ConflictFailure extends Failure {
  const ConflictFailure({super.message = 'Conflict occurred'});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Resource not found'});
}
