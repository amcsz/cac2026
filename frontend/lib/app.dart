import 'package:flutter/material.dart';

import 'pages/auth_gate.dart';

class FastGuardApp extends StatelessWidget {
  const FastGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FastGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f6f73),
          secondary: const Color(0xffb85c38),
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
