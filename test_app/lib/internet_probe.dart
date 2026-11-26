import 'internet_probe_stub.dart'
    if (dart.library.io) 'internet_probe_io.dart'
    if (dart.library.html) 'internet_probe_web.dart' as platform;

/// Checks whether this device can reach the internet.
Future<bool?> hasInternetAccess() => platform.hasInternetAccess();