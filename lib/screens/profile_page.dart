// ============================= profile_page.dart =============================
import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'login_page.dart';
import 'personal_information_page.dart';
import 'saved_addresses_page.dart';
import 'settings_page.dart';

const String _kAppVersion = '1.0.0';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.customer,
    this.onProfileUpdated,
  });
  final Customer customer;
  final ValueChanged<Customer>? onProfileUpdated;

  Future<void> _confirmLogout(BuildContext context) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    AuthService().logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _openPersonalInformation(BuildContext context) async {
    final updated = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => PersonalInformationPage(customer: customer)),
    );

    if (updated != null) {
      onProfileUpdated?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), children: [
      Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
          ),
          child: CircleAvatar(
            radius: 42,
            backgroundColor: colors.surface,
            child: Text(
              customer.initials,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.primary),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(customer.fullName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary)),
      const SizedBox(height: 4),
      Text(customer.mobileNumber, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
      const SizedBox(height: 28),
      _SettingsCard(colors: colors, children: [
        _SettingsTile(
          icon: Icons.person_outline_rounded,
          label: 'Personal information',
          onTap: () => _openPersonalInformation(context),
        ),
        _SettingsDivider(colors: colors),
        _SettingsTile(
          icon: Icons.location_on_outlined,
          label: 'Saved addresses',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesPage())),
        ),
        _SettingsDivider(colors: colors),
        _SettingsTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      ]),
      const SizedBox(height: 16),
      _SettingsCard(colors: colors, children: [
        _SettingsTile(
          icon: Icons.logout_rounded,
          label: 'Log out',
          iconColor: colors.error,
          labelColor: colors.error,
          showChevron: false,
          onTap: () => _confirmLogout(context),
        ),
      ]),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'LaundryLink v$_kAppVersion',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
      ),
    ]);
  }
}

/// Rounded card shell shared by both settings groups, so the account
/// section and the log-out section read as the same "family" of card
/// instead of a plain Material [Card].
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.colors, required this.children});
  final AppColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(children: children),
      );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 16, endIndent: 16, color: colors.border);
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color resolvedIconColor = iconColor ?? colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: resolvedIconColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: resolvedIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
            if (showChevron) Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}