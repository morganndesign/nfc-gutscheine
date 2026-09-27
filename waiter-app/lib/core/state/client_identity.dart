import '../api/api_client.dart';

/// The mutable identity the [ApiClient] reads for every request.
class AppClientIdentity implements ClientIdentity {
  AppClientIdentity({required this.deviceId, required this.userAgent, this.language = 'en'});

  @override
  final String deviceId;

  @override
  final String userAgent;

  @override
  String language;

  @override
  String? token;
}
