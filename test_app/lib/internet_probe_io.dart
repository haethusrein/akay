import 'dart:io';

/// Checks actual HTTPS access, rather than only whether Wi-Fi or mobile data
/// is enabled.
Future<bool?> hasInternetAccess() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4)
    ..idleTimeout = const Duration(seconds: 2);

  try {
    final request = await client
        .getUrl(
          Uri.https('connectivitycheck.gstatic.com', '/generate_204'),
        )
        .timeout(const Duration(seconds: 5));

    request.followRedirects = false;

    final response = await request
        .close()
        .timeout(const Duration(seconds: 5));

    await response.drain<void>();
    return response.statusCode == HttpStatus.noContent;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}