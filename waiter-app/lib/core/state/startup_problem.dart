import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../api/api_failure.dart';
import '../config/environment.dart';

/// Why the app could not start or reach its server. Each kind has its own
/// title and body on the startup problem screen.
enum StartupProblemKind {
  /// The phone has no network connection.
  offline,

  /// The server's host name does not exist (DNS).
  hostNotFound,

  /// Nothing listens at the address (server not started, wrong port).
  refused,

  /// No answer in time / no route to the host.
  timeout,

  /// The TLS certificate was rejected.
  tls,

  /// The server answered with 5xx.
  serverError,

  /// Something answered, but it is not the GiftCard Pro API (404, HTML,
  /// redirect, unexpected JSON) — usually a wrong address.
  invalidResponse,

  /// The build configuration is unusable (no or invalid API address).
  configuration,

  /// The phone's secure storage could not be opened.
  storage,

  /// Anything else, including a start that did not finish in time.
  unknown,
}

/// A startup problem with the technical detail shown in small print.
@immutable
class StartupProblem {
  const StartupProblem(this.kind, {this.detail, this.status, this.requestId});

  /// Classifies a failed `/app/config` request.
  factory StartupProblem.fromApiFailure(ApiFailure failure) => switch (failure) {
        ApiTransportFailure(:final TransportIssue issue, :final String? detail) => StartupProblem(
            switch (issue) {
              TransportIssue.hostLookup => StartupProblemKind.hostNotFound,
              TransportIssue.refused => StartupProblemKind.refused,
              TransportIssue.timeout || TransportIssue.unreachable => StartupProblemKind.timeout,
              TransportIssue.tls => StartupProblemKind.tls,
              TransportIssue.other => StartupProblemKind.unknown,
            },
            detail: detail ?? issue.name,
            requestId: failure.requestId,
          ),
        ApiServerFault(:final int status) when status >= 500 || status == 408 => StartupProblem(
            StartupProblemKind.serverError,
            status: status,
            detail: 'HTTP $status',
            requestId: failure.requestId,
          ),
        // 2xx without a JSON object, redirects, 404 … : not the API.
        ApiServerFault(:final int status) || ApiRejected(:final int status) => StartupProblem(
            StartupProblemKind.invalidResponse,
            status: status,
            detail: 'HTTP $status',
            requestId: failure.requestId,
          ),
        ApiUnauthorized() => StartupProblem(
            StartupProblemKind.invalidResponse,
            status: 401,
            detail: 'HTTP 401',
            requestId: failure.requestId,
          ),
        ApiCancelled() => StartupProblem(StartupProblemKind.unknown, detail: 'cancelled', requestId: failure.requestId),
      };

  /// Classifies an exception thrown while the app starts.
  factory StartupProblem.fromError(Object error) => switch (error) {
        ConfigurationProblem(:final String detail) => StartupProblem(StartupProblemKind.configuration, detail: detail),
        PlatformException(:final String code, :final String? message) => StartupProblem(
            StartupProblemKind.storage,
            detail: _shorten('$code: ${message ?? ''}'),
          ),
        ApiFailure() => StartupProblem.fromApiFailure(error),
        _ => StartupProblem(StartupProblemKind.unknown, detail: _shorten('$error')),
      };

  final StartupProblemKind kind;

  /// Technical detail, e.g. `Failed host lookup: 'app.giftcardpro.at'`.
  final String? detail;

  /// HTTP status, when the server answered.
  final int? status;

  /// `X-Request-Id` of the failed request (support code).
  final String? requestId;

  static String _shorten(String s) => s.length <= 200 ? s : '${s.substring(0, 199)}…';

  @override
  String toString() => 'StartupProblem(${kind.name}${detail == null ? '' : ': $detail'})';
}
