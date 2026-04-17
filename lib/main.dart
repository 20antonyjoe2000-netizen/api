import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MutualFundApp());
}

class MutualFundApp extends StatelessWidget {
  const MutualFundApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}
