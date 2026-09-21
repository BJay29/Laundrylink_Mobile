import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Reusable, "elevated" na text field — icon sa loob ng maliit na
/// colored circle badge (sa halip na plain leading icon), walang
/// makapal na border hanggat hindi naka-focus, at may soft shadow para
/// parang lumulutang ang field sa halip na flat box lang.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.inputFormatters,
    this.prefixText,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  /// Optional na naka-fixed na text bago ang input mismo — hal. "+63 "
  /// sa mobile number field.
  final Widget? prefixText;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13.5),
          filled: true,
          fillColor: colors.surface,
          counterText: maxLength != null ? '' : null,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: colors.primary),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          prefix: prefixText,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.error, width: 1.6),
          ),
        ),
      ),
    );
  }
}