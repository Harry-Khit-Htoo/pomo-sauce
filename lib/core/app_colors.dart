import 'package:flutter/material.dart';

/// The Pomo Sauce palette.
///
/// Tomato red is the brand. There is deliberately no blue anywhere in the
/// app: the two break phases take green (borrowed from the mascot's calyx)
/// and warm amber, which stay distinguishable at a glance without leaving the
/// warm family. Surfaces are a warm cream rather than pure white - flat white
/// next to a saturated red reads cold and makes the red look louder than it is.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFFE9503E);
  static const primaryDeep = Color(0xFFC93A2E);
  static const primaryBright = Color(0xFFF4695A);
  static const accent = Color(0xFFF6A99B);
  static const accentSoft = Color(0xFFFBD3CB);
  static const accentPale = Color(0xFFFFF0EC);

  // Light surfaces (warm cream, never pure white)
  static const lightBackground = Color(0xFFFFF8F5);
  static const lightSurface = Color(0xFFFFFCFA);
  static const lightSurfaceAlt = Color(0xFFFCEEE9);
  static const lightOutline = Color(0xFFF0D8D1);
  static const lightText = Color(0xFF3A1F1A);
  static const lightTextMuted = Color(0xFF8A6259);

  // Dark surfaces (warm near-black, not neutral grey)
  static const darkBackground = Color(0xFF141110);
  static const darkSurface = Color(0xFF1F1A19);
  static const darkSurfaceAlt = Color(0xFF2A2321);
  static const darkOutline = Color(0xFF453A37);
  static const darkText = Color(0xFFF7EBE8);
  static const darkTextMuted = Color(0xFFB59A94);

  // Phase accents
  static const focus = primary;
  static const focusLight = Color(0xFFFF7A69);
  static const shortBreak = Color(0xFF4E9F52);
  static const shortBreakLight = Color(0xFF77C47A);
  static const longBreak = Color(0xFFD4902F);
  static const longBreakLight = Color(0xFFE8B25C);

  // Mascot - sampled from the reference sheet
  static const tomatoTop = Color(0xFFF0543E);
  static const tomatoBottom = Color(0xFFCB2F28);
  static const tomatoTopDark = Color(0xFFF4695A);
  static const tomatoBottomDark = Color(0xFFD13A32);

  /// A slightly muted red for the disappointed moods. Deliberately subtle -
  /// the style guide keeps the body solid tomato-red in every pose, so this
  /// only takes a little life out of it rather than turning it brown.
  static const tomatoTopDull = Color(0xFFE2685A);
  static const tomatoBottomDull = Color(0xFFBE3A31);

  /// Brighter, riper red for the celebrating state.
  static const tomatoTopBright = Color(0xFFFF6A4F);
  static const tomatoBottomBright = Color(0xFFE23A2C);

  static const leaf = Color(0xFF56B04A);
  static const leafDark = Color(0xFF6BC45E);
  static const leafShade = Color(0xFF3A8A34);

  /// Warm dark brown for the mascot's linework - pure black looks harsh on red.
  static const ink = Color(0xFF4A1A14);
  static const blush = Color(0xFFFF8278);
  static const tongue = Color(0xFFFF7E86);
  static const sparkle = Color(0xFFFFC53D);

  static const success = Color(0xFF4E9F52);
  static const warning = Color(0xFFD4902F);
  static const danger = Color(0xFFD13A32);
}
