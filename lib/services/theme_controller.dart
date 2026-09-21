import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide dark mode controller. Singleton, parehong pattern ng
/// CustomerSession. Simple lang: Light o Dark — walang "System default"
/// (sinadyang tinanggal para sa isang malinaw na switch na lang sa
/// Settings, hindi 3-way na radio selection).
class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  static const _prefsKey = 'is_dark_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  /// Tawagin ito sa main() BAGO runApp(), para maload agad ang naka-save
  /// na preference bago mag-build ang unang frame.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefsKey) ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool isDark) async {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isDark);
  }
}