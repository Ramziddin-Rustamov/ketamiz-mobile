import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ui/dialogs/update_dialog.dart';

/// Result of comparing the installed app version against the values published
/// in Firebase Remote Config.
enum UpdateStatus { none, optional, forced }

/// Checks whether a newer app version is available (via Firebase Remote Config)
/// and prompts the user to update.
///
/// Remote Config parameters (set per platform in the Firebase console):
///   - `min_version_android`   / `min_version_ios`   → below this ⇒ FORCED
///   - `latest_version_android`/ `latest_version_ios`→ below this ⇒ OPTIONAL
///   - `store_url_android`     / `store_url_ios`     → where "Update" opens
///
/// Defaults are `0.0.0`, so a fetch failure (or unset params) never blocks or
/// nags anyone — the check simply resolves to [UpdateStatus.none].
class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  bool _initialised = false;

  /// A dialog is currently on screen — don't stack another.
  bool _dialogOpen = false;

  /// An optional prompt has already been shown this session; forced prompts
  /// keep showing until the user updates.
  bool _optionalPromptedThisSession = false;

  /// One-time setup: sensible defaults + fetch settings. Safe to call once at
  /// startup after `Firebase.initializeApp()`.
  Future<void> init() async {
    if (kIsWeb || _initialised) return;
    _initialised = true;
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.setDefaults(const {
        'latest_version_android': '0.0.0',
        'latest_version_ios': '0.0.0',
        'min_version_android': '0.0.0',
        'min_version_ios': '0.0.0',
        'store_url_android':
            'https://play.google.com/store/apps/details?id=uz.ketamiz.app',
        'store_url_ios': 'https://apps.apple.com/app/id0000000000',
      });
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('VersionCheckService.init: $e');
    }
  }

  /// Fetch the latest config, compare versions and show the update dialog when
  /// needed. Call on startup and whenever the app resumes. [context] must be
  /// under a Navigator (the global navigatorKey's context works).
  Future<void> maybePrompt(BuildContext context) async {
    if (kIsWeb || _dialogOpen) return;
    try {
      // Respects minimumFetchInterval, so this is cheap on frequent calls.
      await _rc.fetchAndActivate();
    } catch (_) {
      // Offline / failure — fall through to whatever is cached (or defaults).
    }

    final status = await _evaluate();
    if (status == UpdateStatus.none) return;
    if (status == UpdateStatus.optional && _optionalPromptedThisSession) return;
    if (!context.mounted) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    final storeUrl = _rc.getString('store_url_$platform');
    final forced = status == UpdateStatus.forced;

    _dialogOpen = true;
    if (!forced) _optionalPromptedThisSession = true;
    await showUpdateDialog(context, forced: forced, storeUrl: storeUrl);
    _dialogOpen = false;
  }

  Future<UpdateStatus> _evaluate() async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final latest = _rc.getString('latest_version_$platform');
      final min = _rc.getString('min_version_$platform');
      final current = (await PackageInfo.fromPlatform()).version;

      if (_isLower(current, min)) return UpdateStatus.forced;
      if (_isLower(current, latest)) return UpdateStatus.optional;
      return UpdateStatus.none;
    } catch (e) {
      debugPrint('VersionCheckService._evaluate: $e');
      return UpdateStatus.none;
    }
  }

  /// True when dotted numeric version [a] is strictly lower than [b]
  /// (e.g. "1.1.0" < "1.2.0"). Non-numeric/short parts are treated as 0.
  static bool _isLower(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }

  static List<int> _parts(String v) => v
      .trim()
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
