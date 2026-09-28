import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Feature toggles driven by Firebase Remote Config.
///
/// Remote Config parameters:
///   - `reveal_trip_details` (bool) → show driver name, vehicle plate and the
///     exact start/end points to clients before they book. `false` restores
///     the old privacy behaviour (details only after booking). The driver's
///     phone number is never shown before booking either way.
///
/// Defaults are registered by [VersionCheckService.init] (Remote Config only
/// keeps one defaults map), so [defaults] is the single source of truth.
class FeatureFlags {
  FeatureFlags._();

  static const String _revealTripDetails = 'reveal_trip_details';

  static const Map<String, dynamic> defaults = {
    _revealTripDetails: true,
  };

  /// Whether trip details are open to every logged-in client.
  static bool get revealTripDetails =>
      _getBool(_revealTripDetails, defaults[_revealTripDetails] as bool);

  static bool _getBool(String key, bool fallback) {
    if (kIsWeb) return fallback;
    try {
      final value = FirebaseRemoteConfig.instance.getValue(key);
      // Firebase failed to initialise / key missing everywhere → our default.
      if (value.source == ValueSource.valueStatic) return fallback;
      return value.asBool();
    } catch (_) {
      return fallback;
    }
  }
}
