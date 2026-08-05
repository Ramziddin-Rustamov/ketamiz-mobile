import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

/// Shows the "update available" dialog.
///
/// When [forced] is true the dialog is non-dismissible (no barrier tap, no back
/// button, no "Later") — the user must update to continue. Otherwise it's an
/// optional prompt with a "Later" action.
Future<void> showUpdateDialog(
  BuildContext context, {
  required bool forced,
  required String storeUrl,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !forced,
    builder: (ctx) => PopScope(
      canPop: !forced,
      child: _UpdateDialog(forced: forced, storeUrl: storeUrl),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.forced, required this.storeUrl});

  final bool forced;
  final String storeUrl;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: AppTheme.purple, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              translate(forced ? "update.title_forced" : "update.title"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translate(forced ? "update.message_forced" : "update.message"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                height: 1.5,
                color: AppTheme.gray,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  _openStore();
                  // Optional updates dismiss after sending the user to the
                  // store; forced updates stay up until they actually update.
                  if (!forced) Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.purple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    translate("update.update_now"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (!forced) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      translate("update.later"),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.gray,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
