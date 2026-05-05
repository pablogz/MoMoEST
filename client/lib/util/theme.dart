import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1b3d27),
      surfaceTint: Color(0xff43664e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff32543d),
      onPrimaryContainer: Color(0xffa1c7aa),
      secondary: Color(0xff4f6358),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff8ea397),
      onSecondaryContainer: Color(0xff273930),
      tertiary: Color(0xff735800),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff917000),
      onTertiaryContainer: Color(0xfffffbff),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffaf9f6),
      onSurface: Color(0xff1a1c1a),
      onSurfaceVariant: Color(0xff424842),
      outline: Color(0xff727972),
      outlineVariant: Color(0xffc2c8c0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f312f),
      inversePrimary: Color(0xffaad0b2),
      primaryFixed: Color(0xffc5eccd),
      onPrimaryFixed: Color(0xff00210f),
      primaryFixedDim: Color(0xffaad0b2),
      onPrimaryFixedVariant: Color(0xff2c4e37),
      secondaryFixed: Color(0xffd2e8da),
      onSecondaryFixed: Color(0xff0c1f17),
      secondaryFixedDim: Color(0xffb6ccbf),
      onSecondaryFixedVariant: Color(0xff384b41),
      tertiaryFixed: Color(0xffffdf95),
      onTertiaryFixed: Color(0xff251a00),
      tertiaryFixedDim: Color(0xffedc14b),
      onTertiaryFixedVariant: Color(0xff594400),
      surfaceDim: Color(0xffdadad6),
      surfaceBright: Color(0xfffaf9f6),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff4f4f0),
      surfaceContainer: Color(0xffeeeeea),
      surfaceContainerHigh: Color(0xffe8e8e4),
      surfaceContainerHighest: Color(0xffe2e3df),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1b3d27),
      surfaceTint: Color(0xff43664e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff32543d),
      onPrimaryContainer: Color(0xffcdf4d5),
      secondary: Color(0xff273a31),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff5d7267),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff453400),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff886900),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf9f6),
      onSurface: Color(0xff101210),
      onSurfaceVariant: Color(0xff313832),
      outline: Color(0xff4d544e),
      outlineVariant: Color(0xff686f68),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f312f),
      inversePrimary: Color(0xffaad0b2),
      primaryFixed: Color(0xff52755c),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff3a5c45),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff5d7267),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff46594f),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff886900),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff6a5100),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc6c7c3),
      surfaceBright: Color(0xfffaf9f6),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff4f4f0),
      surfaceContainer: Color(0xffe8e8e4),
      surfaceContainerHigh: Color(0xffddddd9),
      surfaceContainerHighest: Color(0xffd1d2ce),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff10321e),
      surfaceTint: Color(0xff43664e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff2e503a),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1d3027),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff3a4d44),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff392a00),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff5c4600),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf9f6),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff272e28),
      outlineVariant: Color(0xff444b45),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f312f),
      inversePrimary: Color(0xffaad0b2),
      primaryFixed: Color(0xff2e503a),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff173924),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff3a4d44),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff24372e),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff5c4600),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff413000),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb8b9b5),
      surfaceBright: Color(0xfffaf9f6),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff1f1ed),
      surfaceContainer: Color(0xffe2e3df),
      surfaceContainerHigh: Color(0xffd4d5d1),
      surfaceContainerHighest: Color(0xffc6c7c3),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffaad0b2),
      surfaceTint: Color(0xffaad0b2),
      onPrimary: Color(0xff153722),
      primaryContainer: Color(0xff32543d),
      onPrimaryContainer: Color(0xffa1c7aa),
      secondary: Color(0xffb6ccbf),
      onSecondary: Color(0xff22342b),
      secondaryContainer: Color(0xff8ea397),
      onSecondaryContainer: Color(0xff273930),
      tertiary: Color(0xffedc14b),
      onTertiary: Color(0xff3e2e00),
      tertiaryContainer: Color(0xffb28b15),
      onTertiaryContainer: Color(0xff2c1f00),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff121412),
      onSurface: Color(0xffe2e3df),
      onSurfaceVariant: Color(0xffc2c8c0),
      outline: Color(0xff8c928b),
      outlineVariant: Color(0xff424842),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e3df),
      inversePrimary: Color(0xff43664e),
      primaryFixed: Color(0xffc5eccd),
      onPrimaryFixed: Color(0xff00210f),
      primaryFixedDim: Color(0xffaad0b2),
      onPrimaryFixedVariant: Color(0xff2c4e37),
      secondaryFixed: Color(0xffd2e8da),
      onSecondaryFixed: Color(0xff0c1f17),
      secondaryFixedDim: Color(0xffb6ccbf),
      onSecondaryFixedVariant: Color(0xff384b41),
      tertiaryFixed: Color(0xffffdf95),
      onTertiaryFixed: Color(0xff251a00),
      tertiaryFixedDim: Color(0xffedc14b),
      onTertiaryFixedVariant: Color(0xff594400),
      surfaceDim: Color(0xff121412),
      surfaceBright: Color(0xff383a37),
      surfaceContainerLowest: Color(0xff0d0f0d),
      surfaceContainerLow: Color(0xff1a1c1a),
      surfaceContainer: Color(0xff1e201e),
      surfaceContainerHigh: Color(0xff292a28),
      surfaceContainerHighest: Color(0xff333533),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffbfe6c7),
      surfaceTint: Color(0xffaad0b2),
      onPrimary: Color(0xff082c18),
      primaryContainer: Color(0xff75997e),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffcce2d4),
      onSecondary: Color(0xff172921),
      secondaryContainer: Color(0xff8ea397),
      onSecondaryContainer: Color(0xff03140d),
      tertiary: Color(0xffffd878),
      onTertiary: Color(0xff312400),
      tertiaryContainer: Color(0xffb28b15),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff121412),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd7ded6),
      outline: Color(0xffadb4ac),
      outlineVariant: Color(0xff8b928b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e3df),
      inversePrimary: Color(0xff2d4f38),
      primaryFixed: Color(0xffc5eccd),
      onPrimaryFixed: Color(0xff001508),
      primaryFixedDim: Color(0xffaad0b2),
      onPrimaryFixedVariant: Color(0xff1b3d28),
      secondaryFixed: Color(0xffd2e8da),
      onSecondaryFixed: Color(0xff03140d),
      secondaryFixedDim: Color(0xffb6ccbf),
      onSecondaryFixedVariant: Color(0xff273a31),
      tertiaryFixed: Color(0xffffdf95),
      onTertiaryFixed: Color(0xff181000),
      tertiaryFixedDim: Color(0xffedc14b),
      onTertiaryFixedVariant: Color(0xff453400),
      surfaceDim: Color(0xff121412),
      surfaceBright: Color(0xff434542),
      surfaceContainerLowest: Color(0xff060806),
      surfaceContainerLow: Color(0xff1c1e1c),
      surfaceContainer: Color(0xff262826),
      surfaceContainerHigh: Color(0xff313331),
      surfaceContainerHighest: Color(0xff3c3e3c),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd2fada),
      surfaceTint: Color(0xffaad0b2),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffa6ccae),
      onPrimaryContainer: Color(0xff000f05),
      secondary: Color(0xffdff5e8),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffb2c8bb),
      onSecondaryContainer: Color(0xff000e07),
      tertiary: Color(0xffffeece),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffe9bd48),
      onTertiaryContainer: Color(0xff110a00),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff121412),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffebf2e9),
      outlineVariant: Color(0xffbec4bc),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e3df),
      inversePrimary: Color(0xff2d4f38),
      primaryFixed: Color(0xffc5eccd),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffaad0b2),
      onPrimaryFixedVariant: Color(0xff001508),
      secondaryFixed: Color(0xffd2e8da),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb6ccbf),
      onSecondaryFixedVariant: Color(0xff03140d),
      tertiaryFixed: Color(0xffffdf95),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffedc14b),
      onTertiaryFixedVariant: Color(0xff181000),
      surfaceDim: Color(0xff121412),
      surfaceBright: Color(0xff4f504e),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1e201e),
      surfaceContainer: Color(0xff2f312f),
      surfaceContainerHigh: Color(0xff3a3c39),
      surfaceContainerHighest: Color(0xff454745),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
      );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
