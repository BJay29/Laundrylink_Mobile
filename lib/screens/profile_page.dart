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

    // FIX: hindi na kailangan ng headerHeight — hiwalay na row na ang
    // header sa MainNavPage (Column layout, hindi na Positioned
    // background), kaya normal na top padding lang ang kailangan para
    // hindi matakpan ang avatar/pangalan sa taas.
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), children: [
      Center(
        child: CircleAvatar(
          radius: 42,
          backgroundColor: colors.chipBg,
          child: Text(customer.initials, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.textPrimary)),
        ),
      ),
      const SizedBox(height: 14),
      Text(customer.fullName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary)),
      const SizedBox(height: 4),
      Text(customer.mobileNumber, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
      const SizedBox(height: 28),
      Card(
        color: colors.surface,
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.person_outline, color: colors.textPrimary),
            title: Text('Personal information', style: TextStyle(color: colors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
            onTap: () => _openPersonalInformation(context),
          ),
          Divider(height: 1, color: colors.border),
          ListTile(
            leading: Icon(Icons.location_on_outlined, color: colors.textPrimary),
            title: Text('Saved addresses', style: TextStyle(color: colors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
            ),
          ),
          Divider(height: 1, color: colors.border),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: colors.textPrimary),
            title: Text('Settings', style: TextStyle(color: colors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Card(
        color: colors.surface,
        child: ListTile(
          leading: Icon(Icons.logout_rounded, color: colors.error),
          title: Text('Log out', style: TextStyle(color: colors.error, fontWeight: FontWeight.w600)),
          onTap: () => _confirmLogout(context),
        ),
      ),
      const SizedBox(height: 20),
      Center(
        child: Text(
          'LaundryLink v$_kAppVersion',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
      ),
    ]);
  }
}