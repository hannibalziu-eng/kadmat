import 'package:dio/dio.dart';

/// Standardized API error payload parser.
class ApiError {
  final String? code;
  final String message;
  final Map<String, dynamic>? details;
  final String? requestId;
  final int? statusCode;
  final String? path;

  const ApiError({
    required this.message,
    this.code,
    this.details,
    this.requestId,
    this.statusCode,
    this.path,
  });

  String? detailAsString(String key) {
    final value = details?[key];
    if (value == null) return null;
    return value.toString();
  }

  factory ApiError.fromData(dynamic data, {int? statusCode}) {
    if (data is Map<String, dynamic>) {
      final errorNode = data['error'];
      if (errorNode is Map) {
        final errorMap = Map<String, dynamic>.from(errorNode);
        final parsedDetails = errorMap['details'] is Map
            ? Map<String, dynamic>.from(errorMap['details'])
            : null;

        return ApiError(
          code: errorMap['code']?.toString(),
          message:
              errorMap['message']?.toString() ??
              data['message']?.toString() ??
              'Request failed',
          details: parsedDetails,
          requestId: errorMap['requestId']?.toString(),
          statusCode: statusCode,
          path: data['path']?.toString(),
        );
      }

      if (errorNode is String) {
        return ApiError(
          code: null,
          message: errorNode,
          statusCode: statusCode,
          path: data['path']?.toString(),
        );
      }

      if (data['message'] is String) {
        return ApiError(
          code: null,
          message: data['message'].toString(),
          statusCode: statusCode,
          path: data['path']?.toString(),
        );
      }
    }

    if (data is String) {
      return ApiError(message: data, statusCode: statusCode);
    }

    return ApiError(message: 'Request failed', statusCode: statusCode);
  }

  factory ApiError.fromDioException(DioException exception) {
    return ApiError.fromData(
      exception.response?.data,
      statusCode: exception.response?.statusCode,
    );
  }
}
