import 'dart:async';
import 'dart:io' show HandshakeException, SocketException, TlsException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import '../diagnostics/diagnostic_log.dart';
import 'api_failure.dart';

/// Values the client adds to every request (09 §9.1).
abstract interface class ClientIdentity {
  /// Stable per-install id (`X-Device-Id`), 36 characters.
  String get deviceId;

  /// `GiftCardWaiter/<version> (<platform> <os>; <model>)`.
  String get userAgent;

  /// `de`, `en` or `bs` (`Accept-Language`).
  String get language;

  /// Bearer token, or null when signed out.
  String? get token;
}

/// Timeouts from 09 §9.1.
abstract final class ApiTimeouts {
  static const Duration connect = Duration(seconds: 5);
  static const Duration lookup = Duration(seconds: 10);
  static const Duration redeemAttempt = Duration(seconds: 8);
  static const Duration standard = Duration(seconds: 10);
  static const Duration config = Duration(seconds: 2);
}

/// JSON-over-HTTPS transport with the waiter app's request rules: a new
/// `X-Request-Id` per HTTP attempt, device id and language on every call,
/// bearer token when signed in, and error classification per 09 §9.3.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required ClientIdentity identity,
    DiagnosticLog? log,
    Dio? dio,
    Uuid? uuid,
  })  : _identity = identity,
        _log = log,
        _uuid = uuid ?? const Uuid(),
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = ApiTimeouts.connect
      ..responseType = ResponseType.json
      ..followRedirects = false
      // Every status is inspected here; dio must not throw on 4xx/5xx.
      ..validateStatus = (int? status) => status != null;
  }

  final ClientIdentity _identity;
  final DiagnosticLog? _log;

  /// API root (`…/api/v1`); changed when a development or staging build is
  /// pointed at another server.
  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String value) => _dio.options.baseUrl = value;
  final Uuid _uuid;
  final Dio _dio;

  /// Sends one HTTP attempt and returns the decoded JSON object.
  ///
  /// Throws an [ApiFailure]. [timeout] bounds the whole attempt (connect +
  /// send + receive); [cancelToken] lets the caller abort it.
  Future<ApiResponse> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    Map<String, String> headers = const <String, String>{},
    Duration timeout = ApiTimeouts.standard,
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    final String requestId = _uuid.v4();
    final CancelToken token = cancelToken ?? CancelToken();
    bool timedOut = false;
    final Timer timer = Timer(timeout, () {
      timedOut = true;
      token.cancel('timeout');
    });

    final String? bearer = authenticated ? _identity.token : null;
    _log?.record('http.request', '$method $path $requestId');

    try {
      final Response<Object?> response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: token,
        options: Options(
          method: method,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          headers: <String, Object?>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Device-Id': _identity.deviceId,
            'X-Request-Id': requestId,
            'Accept-Language': _identity.language,
            'User-Agent': _identity.userAgent,
            if (bearer != null) 'Authorization': 'Bearer $bearer',
            ...headers,
          },
        ),
      );
      return _interpret(response, requestId);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (timedOut) {
          _log?.record('http.timeout', requestId);
          throw ApiTransportFailure(requestId: requestId, timedOut: true);
        }
        throw ApiCancelled(requestId: requestId);
      }
      final bool isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      final (TransportIssue issue, String? detail) = classifyTransport(e, timedOut: isTimeout);
      _log?.record('http.transport', '${e.type.name} ${issue.name} $requestId');
      throw ApiTransportFailure(requestId: requestId, timedOut: isTimeout, issue: issue, detail: detail);
    } finally {
      timer.cancel();
    }
  }

  /// Maps the network stack's error to a [TransportIssue] (message and OS
  /// error codes of Android/Linux and iOS/macOS).
  @visibleForTesting
  static (TransportIssue, String?) classifyTransport(DioException e, {required bool timedOut}) {
    if (timedOut) return (TransportIssue.timeout, null);
    if (e.type == DioExceptionType.badCertificate) return (TransportIssue.tls, 'certificate rejected');
    final Object? error = e.error;
    final String detail = _shorten('${error ?? e.message ?? e.type.name}');
    if (error is HandshakeException || error is TlsException) return (TransportIssue.tls, detail);
    if (error is SocketException) {
      final String text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      final int? code = error.osError?.errorCode;
      if (text.contains('host lookup') || text.contains('no address associated') || text.contains('nodename nor servname')) {
        return (TransportIssue.hostLookup, detail);
      }
      if (text.contains('connection refused') || code == 111 || code == 61) return (TransportIssue.refused, detail);
      if (text.contains('timed out') || code == 110 || code == 60) return (TransportIssue.timeout, detail);
      if (text.contains('unreachable') || text.contains('no route') || <int>[101, 113, 51, 65].contains(code)) {
        return (TransportIssue.unreachable, detail);
      }
    }
    return (TransportIssue.other, detail);
  }

  static String _shorten(String s) => s.length <= 200 ? s : '${s.substring(0, 199)}…';

  ApiResponse _interpret(Response<Object?> response, String requestId) {
    final int status = response.statusCode ?? 0;
    final Object? data = response.data;
    final Map<String, Object?> json = data is Map ? data.cast<String, Object?>() : const <String, Object?>{};
    _log?.record('http.response', '$status $requestId');

    if (status >= 200 && status < 300) {
      if (data is! Map) throw ApiServerFault(requestId: requestId, status: status);
      return ApiResponse(status: status, json: json, requestId: requestId);
    }
    if (status == 401) {
      final Object? code = json['code'];
      throw ApiUnauthorized(requestId: requestId, code: code is String && code.isNotEmpty ? code : 'UNAUTHENTICATED');
    }
    if (status == 408 || status >= 500 || status < 200) {
      throw ApiServerFault(requestId: requestId, status: status);
    }

    final Object? rawContext = json['context'];
    final Map<String, Object?> context =
        rawContext is Map ? rawContext.cast<String, Object?>() : const <String, Object?>{};
    final Object? code = json['code'];
    final Object? errors = json['errors'];

    throw ApiRejected(
      requestId: requestId,
      status: status,
      code: code is String && code.isNotEmpty ? code : 'HTTP_$status',
      context: context,
      retryAfter: _retryAfter(json, context, response.headers.value('retry-after')),
      fieldErrors: errors is Map
          ? errors.map(
              (Object? k, Object? v) => MapEntry<String, List<String>>(
                '$k',
                v is List ? v.whereType<String>().toList() : const <String>[],
              ),
            )
          : const <String, List<String>>{},
    );
  }

  static Duration? _retryAfter(Map<String, Object?> json, Map<String, Object?> context, String? header) {
    final Object? value = json['retry_after'] ?? context['retry_after'] ?? header;
    final int? seconds = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    return seconds != null && seconds > 0 ? Duration(seconds: seconds) : null;
  }
}

/// A successful (2xx) response.
class ApiResponse {
  const ApiResponse({required this.status, required this.json, required this.requestId});

  final int status;
  final Map<String, Object?> json;
  final String requestId;
}
