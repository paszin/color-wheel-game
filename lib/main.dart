import 'package:flutter/material.dart';

import 'theme/palette.dart';
import 'ui/menu_screen.dart';

void main() => runApp(const ColorWheelApp());

class ColorWheelApp extends StatelessWidget {
  const ColorWheelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farbkreis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: WheelColor.blue.pigment,
          surface: Inks.paper,
        ),
        scaffoldBackgroundColor: Inks.paper,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (final p in TargetPlatform.values)
              p: const FadeForwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
