import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class DefaultTheme {
  final ThemeData theme;
  final ThemeData darkTheme;

  DefaultTheme({required this.theme, required this.darkTheme});
}

// สร้างตัวแปร global ให้เรียกใช้จาก main.dart ได้
final DefaultTheme defaultTheme = DefaultTheme(
  theme: FlexThemeData.light(
    scheme: FlexScheme.indigo,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useTextTheme: true,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  ),
  darkTheme: FlexThemeData.dark(
    scheme: FlexScheme.indigo,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useTextTheme: true,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  ),
);
