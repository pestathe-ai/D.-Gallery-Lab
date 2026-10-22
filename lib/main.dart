import 'package:flutter/material.dart';

import 'ui/app_state.dart';
import 'ui/home_page.dart';

void main() => runApp(const GalleryLabApp());

class GalleryLabApp extends StatefulWidget {
  const GalleryLabApp({super.key});

  @override
  State<GalleryLabApp> createState() => _GalleryLabAppState();
}

class _GalleryLabAppState extends State<GalleryLabApp> {
  final state = AppState();

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B5BDB),
          brightness: b,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 10),
        ),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'D. Gallery Lab',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomePage(state: state),
      );
}
