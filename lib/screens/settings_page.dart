import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/app_colors.dart';
import 'change_password_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('Settings', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionLabel('Account'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: colors.primary,
                iconBg: colors.chipBg,
                title: 'Change password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Appearance'),
          _SettingsCard(
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance.themeMode,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return _SettingsSwitchTile(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconColor: isDark ? colors.primaryLight : colors.warning,
                    iconBg: isDark ? colors.chipBg : colors.warningBg,
                    title: 'Dark mode',
                    subtitle: isDark ? 'On — easier on the eyes at night' : 'Off — using light theme',
                    value: isDark,
                    onChanged: (value) => ThemeController.instance.setDarkMode(value),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Notifications'),
          _SettingsCard(
            children: [
              _SettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                iconColor: colors.success,
                iconBg: colors.successBg,
                title: 'Push notifications',
                subtitle: 'Get notified about your booking updates',
                // ⚠️ ASSUMPTION: local state placeholder lang, hindi pa
                // konektado sa backend (kulang pa akong context sa
                // Customer model / notification preference endpoint).
                value: true,
                onChanged: (_) => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification preference saving is not wired yet.')),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Support'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: colors.primary,
                iconBg: colors.chipBg,
                title: 'Help / FAQ',
                subtitle: 'Get answers to common questions',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                iconColor: colors.primary,
                iconBg: colors.chipBg,
                title: 'Send feedback',
                subtitle: 'Tell us how we can improve',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Legal'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: colors.neutral,
                iconBg: colors.neutralBg,
                title: 'Terms of Service',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: colors.neutral,
                iconBg: colors.neutralBg,
                title: 'Privacy Policy',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),
          Center(
            child: Text('LaundryLink v1.0.0', style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: context.colors.textSecondary,
          ),
        ),
      );
}

/// Rounded card shell na naghahawak ng isa o higit pang tiles — parehong
/// shadow/radius pattern ng ibang cards sa buong app (Home, Booking,
/// atbp.) para consistent ang itsura.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: context.colors.border),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.primary,
          ),
        ],
      ),
    );
  }
}