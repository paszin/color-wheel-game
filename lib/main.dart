import 'package:flutter/material.dart';

import 'audio/sound.dart';
import 'theme/palette.dart';
import 'ui/menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Sound.init();
  runApp(const ColorWheelApp());
}

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
      // Browsers allow audio only after a gesture: the first tap starts it.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => Sound.unlock(),
        child: child,
      ),
      home: const MenuScreen(),
    );
  }
}
