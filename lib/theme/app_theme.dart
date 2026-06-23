import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Custom Color Palette from design tokens
  static const Color bg = Color(0xFFF7F8F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color bgSoft = Color(0xFFF7F7F5);
  static const Color border = Color(0xFFE3E5E1);
  static const Color uiGrey = Color(0xFFECECEC);
  static const Color text = Color(0xFF111820);
  static const Color sub = Color(0xFF6E777C);
  static const Color muted = Color(0xFF8A9296);
  static const Color tealDark = Color(0xFF004B55);
  static const Color teal = Color(0xFF006C74);
  static const Color accent = Color(0xFF22D0CC);
  static const Color navy = Color(0xFF06121B);
  static const Color navyDeep = Color(0xFF010B12);
  static const Color gold = Color(0xFFCDA86A);
  static const Color heart = Color(0xFFF0728A);

  // Brand gradient (応援するボタンと同じ艶感)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF006C74), Color(0xFF0C2030)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Font Styles
  static TextStyle getManrope({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? text,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle getNotoSansJP({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.notoSansJp(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? text,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Application Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        surface: card,
        primary: teal,
        secondary: accent,
        onPrimary: Colors.white,
        onSecondary: text,
        onSurface: text,
        outline: border,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: text),
        titleTextStyle: GoogleFonts.notoSansJp(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }

  static Widget buildImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        width: width,
        height: height,
      );
    } else {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: teal),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 24),
        ),
      );
    }
  }
}
