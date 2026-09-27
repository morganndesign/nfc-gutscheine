import 'package:flutter/foundation.dart';

/// A gift card URL as written to the NFC chip or printed as QR code:
/// `https://<card domain>/c/<uuid>` — for NTAG 424 DNA with the one-time
/// `picc` and `cmac` parameters (09 §7.1 validation, 03b §1.2).
@immutable
class CardLink {
  const CardLink._(this.url, this.token, this.isSunSigned);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Returns the link when [raw] is a card URL on one of [allowedHosts];
  /// otherwise null (→ `scan.notCard`, no request is sent).
  ///
  /// [allowHttp] (development environment) also accepts `http` so a local
  /// stack can be used; when null, debug builds accept it.
  static CardLink? parse(String raw, List<String> allowedHosts, {bool? allowHttp}) {
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;

    final bool http = allowHttp ?? !kReleaseMode;
    final bool schemeOk = uri.scheme == 'https' || (http && uri.scheme == 'http');
    if (!schemeOk || !allowedHosts.contains(uri.host.toLowerCase())) return null;

    final List<String> segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != 'c' || !_uuid.hasMatch(segments.last)) return null;

    final bool signed = (uri.queryParameters['picc'] ?? '').isNotEmpty &&
        (uri.queryParameters['cmac'] ?? '').isNotEmpty;

    return CardLink._(uri.toString(), segments.last, signed);
  }

  /// The full URL, sent unchanged as `token` to `POST /scan` (the server
  /// verifies `picc`/`cmac`).
  final String url;

  /// The public card token (UUID).
  final String token;

  /// True for NTAG 424 DNA URLs: such a URL is single-use and is never
  /// re-posted (03b §1.2).
  final bool isSunSigned;
}
