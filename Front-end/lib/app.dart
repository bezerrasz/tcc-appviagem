import 'package:flutter/material.dart';
import 'package:test_tcc/core/theme/app_theme.dart';
import 'package:test_tcc/presentation/app/auth_gate.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Share a Ride',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
