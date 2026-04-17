import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(const MutualFundApp());
}

class MutualFundApp extends StatefulWidget {
  const MutualFundApp({super.key});

  @override
  State<MutualFundApp> createState() => _MutualFundAppState();
}

class _MutualFundAppState extends State<MutualFundApp> {
  final _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MF Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
