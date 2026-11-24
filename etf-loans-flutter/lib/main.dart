import 'package:flutter/material.dart';
import 'package:etf_loans/core/constants/app_routes.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:etf_loans/features/authentication/screens/login_screen.dart';
import 'package:etf_loans/features/welcome/welcome_screen.dart';
import 'package:etf_loans/features/legal/terms_screen.dart';
import 'package:etf_loans/features/legal/privacy_screen.dart';

void main() {
  runApp(const ETFLoansApp());
}

class ETFLoansApp extends StatelessWidget {
  const ETFLoansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETF Loans',
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.light,
      home: const WelcomeScreen(),
      routes: {
        AppRoutes.signIn: (_) => const LoginScreen(),
        AppRoutes.terms: (_) => const TermsScreen(),
        AppRoutes.privacy: (_) => const PrivacyScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}