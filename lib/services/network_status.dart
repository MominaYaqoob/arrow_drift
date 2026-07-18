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
      // If the platform channel itself fails (rare, but seen on some
      // heavily-customized OEM Android builds), assume online rather than
      // permanently locking the app out of ads over a connectivity-check
      // bug — every ad call downstream is still individually guarded.
      debugPrint('NetworkStatus: checkConnectivity failed, assuming online: $e');
      return true;
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
