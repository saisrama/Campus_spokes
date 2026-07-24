import 'package:flutter/material.dart';

// ──────────────────────────────────────────────
// RentX Vercel / 21st.dev Design System
// Pure black, zinc surfaces, clean borders
// ──────────────────────────────────────────────

// Background colors
const Color kBgColor       = Color(0xFF000000); // Page background
const Color kSurface1      = Color(0xFF09090B); // Cards / primary surfaces
const Color kSurface2      = Color(0xFF18181B); // Secondary / nested surfaces
const Color kBorder        = Color(0xFF27272A); // Default border

// Text colors
const Color kTextPrimary   = Color(0xFFFAFAFA); // Headings / main text
const Color kTextMuted     = Color(0xFFA1A1AA); // Subtitles / description
const Color kTextDim       = Color(0xFF71717A); // Placeholder / captions

// Accent colors
const Color kAccentCyan    = Color(0xFF38BDF8);
const Color kAccentViolet  = Color(0xFF818CF8);
const Color kAccentOrange  = Color(0xFFFB923C);
const Color kAccentGreen   = Color(0xFF34D399);
const Color kAccentRed     = Color(0xFFF87171);
const Color kAccentAmber   = Color(0xFFFBBF24);

// ──────────────────────────────────────────────
// Reusable widget helpers
// ──────────────────────────────────────────────

/// Standard Vercel-style app bar with consistent styling
AppBar rentXAppBar(BuildContext context, String title, {String? subtitle, List<Widget>? actions}) {
  return AppBar(
    backgroundColor: kBgColor,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: kTextPrimary),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.3)),
        if (subtitle != null)
          Text(subtitle, style: const TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.normal)),
      ],
    ),
    actions: actions,
  );
}

/// Standard card container
Widget rentXCard({required Widget child, EdgeInsets? padding, Color? borderColor}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kSurface1,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? kBorder),
    ),
    child: child,
  );
}

/// Standard text field input
InputDecoration rentXInputDecoration(String label, {String? hint, Widget? suffix, Widget? prefix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: kTextMuted, fontSize: 13),
    hintStyle: const TextStyle(color: kTextDim, fontSize: 13),
    filled: true,
    fillColor: kSurface2,
    suffixIcon: suffix,
    prefixIcon: prefix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kTextMuted),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kAccentRed.withValues(alpha: 0.6)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

/// Section label for forms
Widget rentXSectionLabel(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 8.0),
  child: Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
);

/// Primary action button
Widget rentXButton({required String label, required VoidCallback? onTap, bool loading = false, Color? color, IconData? icon}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? kTextPrimary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
    ),
  );
}

/// Empty state widget
Widget rentXEmptyState({required IconData icon, required String message, String? subMessage, Widget? action}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kSurface1,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, size: 40, color: kTextDim),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          if (subMessage != null) ...[
            const SizedBox(height: 6),
            Text(subMessage, style: const TextStyle(color: kTextMuted, fontSize: 13), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 24), action],
        ],
      ),
    ),
  );
}

/// Status badge (chip)
Widget rentXBadge(String label, {Color? color}) {
  final c = color ?? kTextMuted;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

/// Divider in Vercel style
Widget rentXDivider() => const Divider(color: kBorder, height: 1);
