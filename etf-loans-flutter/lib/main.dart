import 'package:flutter/material.dart';
import 'package:etf_loans/core/constants/app_routes.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:etf_loans/features/authentication/screens/login_screen.dart';
import 'package:etf_loans/features/authentication/screens/home_screen.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etf_loans/features/welcome/welcome_screen.dart';
import 'package:etf_loans/features/legal/terms_screen.dart';
import 'package:etf_loans/features/legal/privacy_screen.dart';

void main() {
  runApp(const ETFLoansApp());
}

class ETFLoansApp extends StatelessWidget {
  const ETFLoansApp({this.authenticationService, super.key});

  final AuthenticationService? authenticationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETF Loans',
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.light,
      home: _SessionEntry(authenticationService),
      routes: {
        AppRoutes.signIn: (_) => _SessionEntry(
          authenticationService,
          child: LoginScreen(authenticationService: authenticationService),
        ),
        AppRoutes.terms: (_) => const TermsScreen(),
        AppRoutes.privacy: (_) => const PrivacyScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SessionEntry extends StatefulWidget {
  const _SessionEntry(
    this.authenticationService, {
    this.child = const WelcomeScreen(),
  });

  final AuthenticationService? authenticationService;
  final Widget child;

  @override
  State<_SessionEntry> createState() => _SessionEntryState();
}

class _SessionEntryState extends State<_SessionEntry> {
  static const _storage = FlutterSecureStorage();
  late final _auth = widget.authenticationService ?? AuthenticationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
    String? token;
    try {
      token = await _storage.read(key: 'accessToken');
      final storedToken = token;
      if (!mounted || storedToken == null || storedToken.isEmpty) return;
      final user = await _auth.getUserProfile(accessToken: storedToken);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (await _storage.read(key: 'accessToken') != storedToken) return;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              HomeScreen(initialUser: user, initialToken: storedToken),
        ),
      );
    } on InvalidSessionException {
      if (token != null && await _storage.read(key: 'accessToken') == token) {
        await _storage.delete(key: 'accessToken');
      }
    } catch (_) {
      // Keep the public entry point usable when secure storage or the API is offline.
    }
  }

  @override
  void dispose() {
    if (widget.authenticationService == null) _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
