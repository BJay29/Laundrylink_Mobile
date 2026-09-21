import 'dart:ui' show PointerDeviceKind;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_page.dart';
import 'services/supabase_config.dart';
import 'services/theme_controller.dart';
import 'theme/app_colors.dart';

/// Convenience getter na ginagamit sa buong app (auth_service.dart,
/// api_service.dart, atbp.) para ma-access ang Supabase client nang
/// hindi na kailangang i-import ang buong package kada file.
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();

  // Gamitin ang SupabaseConfig service para sa initialization
  await SupabaseConfig.initialize();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const LaundryLinkApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class LaundryLinkApp extends StatelessWidget {
  const LaundryLinkApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'LaundryLink',
          debugShowCheckedModeBanner: false,
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          scrollBehavior: AppScrollBehavior(),
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1769E0)),
            scaffoldBackgroundColor: AppColors.light.background,
            extensions: const [AppColors.light],
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1769E0),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: AppColors.dark.background,
            extensions: const [AppColors.dark],
          ),
          home: const SplashPage(),
        ),
      );
}