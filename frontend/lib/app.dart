import 'package:flutter/material.dart';

import 'pages/auth_gate.dart';

class SwiftGuardApp extends StatelessWidget {
  const SwiftGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwiftGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0f3a5f),
          secondary: const Color(0xff2d5f8f),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
