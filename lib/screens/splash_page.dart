import 'package:flutter/material.dart';

import '../services/customer_session.dart';
import '../theme/app_colors.dart';
import 'main_nav_page.dart';
import 'welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// NEW — dating plain 3.5s delay lang bago Welcome page palagi. Ngayon,
  /// tinatawag muna ang restoreSession() (kukunin ang naka-sync na
  /// customer profile kung may existing Supabase session pa — awtomatiko
  /// na itong na-restore mismo ni Supabase mula sa encrypted disk
  /// storage nito noong Supabase.initialize() sa main.dart), tapos
  /// saka lang magdedesisyon papunta saan: MainNavPage (kung naka-login)
  /// o WelcomePage (kung hindi).
  Future<void> _bootstrap() async {
    final splashDelay = Future.delayed(const Duration(milliseconds: 2000));
    await CustomerSession.instance.restoreSession();
    // Sinasadyang hinihintay pa rin ang minimum na 2s splash duration
    // kahit mabilis matapos ang restoreSession(), para hindi masyadong
    // "kumurap" lang ang splash screen sa mabilis na koneksyon.
    await splashDelay;

    if (!mounted) return;

    final customer = CustomerSession.instance.customer;
    if (customer != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainNavPage(customer: customer)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: Center(
          child: Image.asset(
            'assets/images/Untitled design.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      );
}

class LaundryLinkLogo extends StatelessWidget {
  const LaundryLinkLogo({
    super.key,
    required this.fontSize,
  });

  final double fontSize;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: 'LAUNDRY', style: TextStyle(color: Color(0xFF6D28D9))),
                TextSpan(text: 'LINK', style: TextStyle(color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      );
}