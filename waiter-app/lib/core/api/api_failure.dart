import 'package:flutter/foundation.dart';

/// Every way an API call can fail, classified as 09 §9.3 requires. The app
/// switches on [ApiRejected.code], never on messages.
@immutable
sealed class ApiFailure implements Exception {
  const ApiFailure({required this.requestId});

  /// `X-Request-Id` of the (last) HTTP attempt; its last 6 characters are the
  /// support code (12 §2.5).
  final String requestId;
}

/// A definitive answer from the server (4xx except 401): nothing was booked.
final class ApiRejected extends ApiFailure {
  const ApiRejected({
    required super.requestId,
    required this.status,
    required this.code,
    required this.context,
    this.retryAfter,
    this.fieldErrors = const <String, List<String>>{},
  });

  final int status;

  /// Stable machine code, e.g. `CARD_NOT_FOUND`; `HTTP_<status>` when the body
  /// carried none.
  final String code;
  final Map<String, Object?> context;

  /// From `retry_after` (body, context or header), for 423 / 429.
  final Duration? retryAfter;
  final Map<String, List<String>> fieldErrors;

  int? contextInt(String key) {
    final Object? value = context[key];
    return value is num ? value.toInt() : null;
  }

  String? contextString(String key) {
    final Object? value = context[key];
    return value is String ? value : null;
  }

  @override
  String toString() => 'ApiRejected($status $code)';
}

/// 401 — session class (S15 session sheet), or `ACCOUNT_DEACTIVATED` (Q2).
final class ApiUnauthorized extends ApiFailure {
  const ApiUnauthorized({required super.requestId, this.code = 'UNAUTHENTICATED'});

  final String code;

  bool get isDeactivated => code == 'ACCOUNT_DEACTIVATED';

  @override
  String toString() => 'ApiUnauthorized($code)';
}

/// 5xx, 408 or an unreadable response: the request may have been processed.
final class ApiServerFault extends ApiFailure {
  const ApiServerFault({required super.requestId, required this.status});

  final int status;

  @override
  String toString() => 'ApiServerFault($status)';
}

/// Why no response arrived (for the startup problem screen; the redeem and
/// lookup flows only distinguish [ApiTransportFailure.timedOut]).
enum TransportIssue {
  /// No answer within the time limit.
  timeout,

  /// The host name does not resolve (DNS): wrong or unregistered domain.
  hostLookup,

  /// The host answered but nothing listens on the port (server not started).
  refused,

  /// No route to the host (other network, VPN, firewall).
  unreachable,

  /// TLS handshake or certificate rejected.
  tls,

  /// Anything else (connection reset, …).
  other,
}

/// No response: timeout, reset, DNS or TLS failure. For a redeem the outcome is
/// unknown (uncertain class); for a lookup it is a network problem.
final class ApiTransportFailure extends ApiFailure {
  const ApiTransportFailure({required super.requestId, required this.timedOut, TransportIssue? issue, this.detail})
      : issue = issue ?? (timedOut ? TransportIssue.timeout : TransportIssue.other);

  final bool timedOut;

  /// Classified cause.
  final TransportIssue issue;

  /// Technical description from the network stack, e.g.
  /// `Failed host lookup: 'app.giftcardpro.at'`.
  final String? detail;

  @override
  String toString() => 'ApiTransportFailure(${issue.name}${detail == null ? '' : ': $detail'})';
}

/// The app aborted the request itself (e.g. the 8 s slow-redeem restart).
final class ApiCancelled extends ApiFailure {
  const ApiCancelled({required super.requestId});

  @override
  String toString() => 'ApiCancelled';
}
