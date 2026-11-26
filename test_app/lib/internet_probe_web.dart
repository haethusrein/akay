import 'dart:html' as html;

/// Checks actual HTTPS access in a browser.
Future<bool?> hasInternetAccess() async {
  try {
    final response = await html.HttpRequest.request(
      'https://connectivitycheck.gstatic.com/generate_204',
      method: 'GET',
    ).timeout(const Duration(seconds: 8));

    return response.status == 204;
  } catch (_) {
    return false;
  }
}