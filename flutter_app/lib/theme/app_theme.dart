import 'package:flutter/material.dart';

/// The brand theme for one tenant, as sent by /app/v1 (theme block).
class BrandTheme {
  final Color primary; // actions: buttons, selection, links
  final String mode; // auto | light | dark
  final String language; // en | bn
  final int rev;

  const BrandTheme({
    required this.primary,
    this.mode = 'auto',
    this.language = 'en',
    this.rev = 1,
  });

  /// Fallback used before the first bootstrap completes.
  static const fallback = BrandTheme(primary: Color(0xFF4338CA));

  factory BrandTheme.fromJson(Map<String, dynamic> j) => BrandTheme(
        primary: _hex(j['primary'] as String?) ?? const Color(0xFF4338CA),
        mode: (j['mode'] as String?) ?? 'auto',
        language: (j['language'] as String?) ?? 'en',
        rev: (j['rev'] as int?) ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'primary': '#${primary.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'mode': mode,
        'language': language,
        'rev': rev,
      };

  static Color? _hex(String? s) {
    if (s == null) return null;
    s = s.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }

  ThemeMode get themeMode => switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Status colours are fixed across every tenant so agents learn them once;
  /// only the brand [primary] (actions) changes per company.
  static const available = Color(0xFF16A34A);
  static const onCall = Color(0xFF0891B2);
  static const onBreak = Color(0xFFD97706);
  static const dnd = Color(0xFFDC2626);
  static const offline = Color(0xFF8A94A3);

  ThemeData light() => _build(Brightness.light);
  ThemeData dark() => _build(Brightness.dark);

  ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: b,
      primary: primary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          b == Brightness.light ? const Color(0xFFF4F5F9) : const Color(0xFF0E1330),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      fontFamily: language == 'bn' ? 'HindSiliguri' : null,
    );
  }
}
