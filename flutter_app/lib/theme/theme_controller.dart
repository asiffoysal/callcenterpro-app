import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Holds the active [BrandTheme] and rebuilds the app when it changes.
///
/// Sources, in order:
///  1. a value cached on the device (instant, no flash on launch)
///  2. the /app/v1 bootstrap response at sign-in
///  3. a `theme.update` event from the realtime hub (admin changed the
///     colour in the control panel) — applied live, no restart.
class ThemeController extends ChangeNotifier {
  BrandTheme _theme = BrandTheme.fallback;
  BrandTheme get theme => _theme;

  static const _key = 'brand_theme';

  Future<void> loadCached() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        _theme = BrandTheme.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {/* ignore bad cache */}
    }
  }

  /// Apply a theme from the server. Ignores stale revisions so an out-of-order
  /// websocket message can't roll the colour back.
  Future<void> apply(BrandTheme next) async {
    if (next.rev < _theme.rev) return;
    _theme = next;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(next.toJson()));
  }

  /// Handle a raw `theme.update` payload from the realtime hub.
  void onRealtimeThemeUpdate(Map<String, dynamic> data) {
    apply(BrandTheme.fromJson(data));
  }
}
