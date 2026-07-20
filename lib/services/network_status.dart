import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Thin, defensive wrapper around `connectivity_plus`.
///
/// Note (per the package's own docs): this reports network *type*
/// availability (Wi-Fi / mobile / etc.), not a guarantee of live internet
/// access — a device can report "connected" to a Wi-Fi network with no
/// actual internet (e.g. a hotel captive portal). That's fine for our
/// purpose here: gating ad requests so they don't fire into a connection
/// that's obviously absent, not proving connectivity with certainty. Ad
/// SDK calls remain defensively error-handled regardless (see
/// AdsServiceImpl), so this is a fast-path optimization, not the only
/// safety net.
class NetworkStatus {
  NetworkStatus._();
  static final NetworkStatus instance = NetworkStatus._();

  final Connectivity _connectivity = Connectivity();

  /// One-shot check — used at launch before deciding whether to
  /// initialize the ad SDK at all.
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      // For strict online-only gameplay, treat check failures as offline.
      // Ads still have their own try/catch safety nets.
      debugPrint('NetworkStatus: checkConnectivity failed, assuming offline: $e');
      return false;
    }
  }

  /// Live updates — used after launch so ad calls can keep gracefully
  /// backing off if the connection drops mid-session (e.g. airplane mode),
  /// without needing to re-check on every single ad request.
  Stream<bool> get onChanged {
    return _connectivity.onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none))
        .handleError((Object e) {
      debugPrint('NetworkStatus: onConnectivityChanged error: $e');
    });
  }
}
