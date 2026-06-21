import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';

/// Champ de saisie standard (`.fts-input`).
class FtsTextField extends StatelessWidget {
  const FtsTextField({
    super.key,
    this.hint,
    this.icon,
    this.controller,
    this.onChanged,
  });

  final String? hint;
  final IconData? icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 13.5, color: FtsColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA3B7), fontSize: 13.5),
        prefixIcon: icon != null ? Icon(icon, size: 17, color: FtsColors.muted) : null,
        filled: true,
        fillColor: FtsColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: FtsRadius.smRadius,
          borderSide: const BorderSide(color: FtsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FtsRadius.smRadius,
          borderSide: const BorderSide(color: FtsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FtsRadius.smRadius,
          borderSide: const BorderSide(color: FtsColors.blue500, width: 1.5),
        ),
      ),
    );
  }
}

/// Sélecteur déroulant standard (`.fts-select`).
class FtsSelect<T> extends StatelessWidget {
  const FtsSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FtsColors.surface,
        borderRadius: FtsRadius.smRadius,
        border: Border.all(color: FtsColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: FtsColors.muted),
          style: GoogleFonts.inter(fontSize: 13.5, color: FtsColors.ink),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Bouton-icône circulaire/carré (`.fts-icon-action`), ex: refresh.
class FtsIconAction extends StatelessWidget {
  const FtsIconAction({super.key, required this.icon, this.onTap, this.active = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? FtsColors.blue100 : FtsColors.surface,
      borderRadius: FtsRadius.smRadius,
      child: InkWell(
        borderRadius: FtsRadius.smRadius,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: FtsRadius.smRadius,
            border: Border.all(color: active ? FtsColors.blue700 : FtsColors.border),
          ),
          child: Icon(icon, size: 16, color: active ? FtsColors.blue700 : FtsColors.muted),
        ),
      ),
    );
  }
}
