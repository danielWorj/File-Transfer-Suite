import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens FTS — transposition directe des variables CSS
/// de `fts-base.css` (.fts-app) pour l'application mobile Flutter.
///
/// Toute couleur, rayon ou style de texte utilisé dans l'app doit
/// provenir de cette classe : aucune valeur "en dur" dans les vues.
class FtsColors {
  FtsColors._();

  static const blue900 = Color(0xFF14224F);
  static const blue700 = Color(0xFF1A2E66); // couleur primaire
  static const blue600 = Color(0xFF24398C);
  static const blue500 = Color(0xFF2F5DD0); // accent interactif
  static const blue100 = Color(0xFFEEF2FC); // fond bleu très pâle
  static const blue050 = Color(0xFFF6F8FC); // fond de page

  static const ink = Color(0xFF1A1F2B);
  static const muted = Color(0xFF66708A);
  static const border = Color(0xFFDCE2EC);
  static const borderStrong = Color(0xFFC3CCDE);
  static const surface = Color(0xFFFFFFFF);

  static const success = Color(0xFF1E8E5A);
  static const successSoft = Color(0xFFE8F6EF);
  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFBEAEA);
  static const warning = Color(0xFFA9740F);
  static const warningSoft = Color(0xFFFBF3E2);
}

class FtsRadius {
  FtsRadius._();

  static const sm = 3.0;
  static const md = 4.0;

  static const cardRadius = BorderRadius.all(Radius.circular(md));
  static const smRadius = BorderRadius.all(Radius.circular(sm));
}

class FtsSpacing {
  FtsSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Polices : Sora (display), Inter (corps), IBM Plex Mono (mono / labels).
///
/// IMPORTANT — avec le package `google_fonts`, on n'utilise JAMAIS
/// `fontFamily: 'Sora'` directement dans un TextStyle : la police
/// n'est pas déclarée comme asset dans pubspec.yaml, donc Flutter ne
/// la trouverait pas (fallback silencieux sur la police système, ou
/// erreur selon les cas). Il faut passer par les fonctions
/// `GoogleFonts.sora(...)`, `GoogleFonts.inter(...)`, etc., qui
/// téléchargent/mettent en cache la police et retournent un
/// TextStyle déjà correctement configuré.
class FtsText {
  FtsText._();

  static TextStyle get title => GoogleFonts.sora(
        fontWeight: FontWeight.w600,
        fontSize: 21.0,
        color: FtsColors.blue900,
        letterSpacing: -0.2,
        height: 1.2,
      );

  static TextStyle get cardTitle => GoogleFonts.sora(
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
        color: FtsColors.blue900,
      );

  static TextStyle get subtitle => GoogleFonts.inter(
        fontSize: 13.5,
        color: FtsColors.muted,
        height: 1.45,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14.0,
        color: FtsColors.ink,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
        color: FtsColors.ink,
      );

  static TextStyle get eyebrow => GoogleFonts.ibmPlexMono(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: FtsColors.blue500,
        letterSpacing: 1.4,
      );

  static TextStyle get mono => GoogleFonts.ibmPlexMono(
        fontSize: 12.0,
        color: FtsColors.muted,
      );

  static TextStyle get statValue => GoogleFonts.ibmPlexMono(
        fontWeight: FontWeight.w500,
        fontSize: 19.0,
        color: FtsColors.blue900,
      );

  static TextStyle get statLabel => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: FtsColors.muted,
        letterSpacing: 0.6,
      );

  static TextStyle get navLabel => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 10.5,
      );
}

class FtsTheme {
  FtsTheme._();

  static ThemeData get light {
    final base = ThemeData.light();

    // textTheme global construit avec GoogleFonts.interTextTheme,
    // pour que tous les widgets Material (boutons, champs, etc. qui
    // n'utilisent pas explicitement FtsText) héritent aussi d'Inter
    // au lieu de la police système par défaut.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: FtsColors.ink,
      displayColor: FtsColors.blue900,
    );

    return base.copyWith(
      scaffoldBackgroundColor: FtsColors.blue050,
      primaryColor: FtsColors.blue700,
      colorScheme: base.colorScheme.copyWith(
        primary: FtsColors.blue700,
        secondary: FtsColors.blue500,
        error: FtsColors.danger,
        surface: FtsColors.surface,
      ),
      textTheme: textTheme,
      dividerColor: FtsColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: FtsColors.surface,
        foregroundColor: FtsColors.blue900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.sora(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: FtsColors.blue900,
        ),
      ),
      useMaterial3: true,
    );
  }
}
