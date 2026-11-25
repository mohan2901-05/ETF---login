import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:etf_loans/core/constants/app_routes.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/eligibility/eligibility_flow.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_flow.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile? initialUser;
  final String? initialToken;
  final BorrowerService borrowerService;
  final EligibilityService eligibilityService;

  const HomeScreen({
    this.initialUser,
    this.initialToken,
    this.borrowerService = const UnavailableBorrowerService(),
    this.eligibilityService = const UnavailableEligibilityService(),
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthenticationService _authService;
  late final FlutterSecureStorage _secureStorage;

  UserProfile? _user;
  String? _accessToken;
  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _openingBorrowerFlow = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthenticationService(networkService: NetworkService());
    _secureStorage = const FlutterSecureStorage();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      _accessToken = widget.initialToken ?? await _secureStorage.read(key: 'accessToken');

      if (widget.initialUser != null && widget.initialToken != null) {
        _user = widget.initialUser;
      } else if (_accessToken != null) {
        _user = await _authService.getUserProfile(accessToken: _accessToken!);
      }
    } on InvalidSessionException {
      await _secureStorage.delete(key: 'accessToken');
      if (mounted) _returnToSignIn();
    } on AppError catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load user profile';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      final token = _accessToken;
      if (token != null && token.isNotEmpty) {
        await _authService.logout(accessToken: token);
      }
      await _secureStorage.delete(key: 'accessToken');
      if (mounted) _returnToSignIn();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-out failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _returnToSignIn() {
    final navigator = Navigator.of(context);
    var foundSignIn = false;
    navigator.popUntil((route) {
      foundSignIn = route.settings.name == AppRoutes.signIn;
      return foundSignIn || route.isFirst;
    });
    if (!foundSignIn) navigator.pushNamed(AppRoutes.signIn);
  }

  Future<void> _openBorrowerFlow({required bool update}) async {
    final token = _accessToken;
    final user = _user;
    if (_openingBorrowerFlow ||
        _isSigningOut ||
        user == null ||
        token == null ||
        token.isEmpty) {
      return;
    }

    setState(() => _openingBorrowerFlow = true);
    try {
      final result = await _pushBorrowerDetails(
        update: update,
        token: token,
        accountName: user.name,
      );
      if (!mounted || result == null) return;
      if (result == BorrowerFlowResult.sessionExpired) {
        await _expireBorrowerSession(token);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/checking'),
          builder: (_) => EligibilityFlow(
            accessToken: token,
            borrowerName: user.name,
            initialKind: result == BorrowerFlowResult.checkEligibility
                ? EligibilityCheckKind.initial
                : EligibilityCheckKind.recheck,
            service: widget.eligibilityService,
            openUpdateDetails: () => _pushBorrowerDetails(
              update: true,
              token: token,
              accountName: user.name,
            ),
            onSessionExpired: () => _expireBorrowerSession(token),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingBorrowerFlow = false);
    }
  }

  Future<BorrowerFlowResult?> _pushBorrowerDetails({
    required bool update,
    required String token,
    required String? accountName,
  }) {
    return Navigator.of(context).push<BorrowerFlowResult>(
      MaterialPageRoute(
        settings: RouteSettings(name: update ? '/update' : '/details'),
        builder: (_) => BorrowerFlow(
          accessToken: token,
          openUpdate: update,
          accountName: accountName,
          service: widget.borrowerService,
        ),
      ),
    );
  }

  Future<void> _expireBorrowerSession(String token) async {
    if (_accessToken != token) return;
    setState(() {
      _accessToken = null;
      _user = null;
    });
    try {
      if (await _secureStorage.read(key: 'accessToken') == token) {
        await _secureStorage.delete(key: 'accessToken');
      }
    } catch (_) {
      // A storage failure does not make an expired session usable.
    }
    if (mounted) _returnToSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.paperBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: ThemeConfig.primaryGreen),
              )
            : _errorMessage != null
                ? _buildErrorView()
                : _user == null
                    ? const Center(child: Text('No user data'))
                    : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: ThemeConfig.errorRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: ThemeConfig.bodyFontFamily,
                fontSize: 16,
                color: ThemeConfig.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.primaryGreen,
                foregroundColor: ThemeConfig.onDeep,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThemeConfig.cardBg,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusLarge),
        border: Border.all(color: ThemeConfig.ruleStrong),
        boxShadow: ThemeConfig.shadowBase,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ThemeConfig.tintGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_circle_rounded,
                  size: 32,
                  color: ThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontFamily: ThemeConfig.bodyFontFamily,
                        fontSize: 14,
                        color: ThemeConfig.mutedText,
                      ),
                    ),
                    Text(
                      (_user!.name?.isNotEmpty ?? false) ? _user!.name! : 'User',
                      style: TextStyle(
                        fontFamily: ThemeConfig.headingFontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ThemeConfig.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: ThemeConfig.ruleStrong),
          const SizedBox(height: 16),
          _buildInfoRow('Mobile', _formatMobileNumber(_user!.mobileNumber)),
          const SizedBox(height: 12),
          if (_user!.email != null && _user!.email!.isNotEmpty)
            _buildInfoRow('Email', _user!.email!),
          const SizedBox(height: 12),
          if (_user!.createdAt != null && _user!.createdAt!.isNotEmpty)
            _buildInfoRow('Member since', _user!.createdAt!),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildActionButtons() {
    final actionsEnabled = !_isSigningOut && !_openingBorrowerFlow;
    final borrowerActionsEnabled = actionsEnabled && (_accessToken?.isNotEmpty ?? false);
    return Column(
      children: [
        OutlineButton(
          title: 'Personal details',
          onPressed: () => _openBorrowerFlow(update: false),
          enabled: borrowerActionsEnabled,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: actionsEnabled ? _logout : null,
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.errorRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusButton),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
        const SizedBox(height: 16),
        TextButton(
          onPressed: borrowerActionsEnabled
              ? () => _openBorrowerFlow(update: true)
              : null,
          style: TextButton.styleFrom(
            foregroundColor: ThemeConfig.primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            'Manage Account',
            style: TextStyle(
              fontFamily: ThemeConfig.bodyFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: ThemeConfig.bodyFontFamily,
              fontSize: 14,
              color: ThemeConfig.mutedText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: ThemeConfig.bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ThemeConfig.ink,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMobileNumber(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return mobile;
  }

  @override
  void dispose() {
    _authService.close();
    super.dispose();
  }
}
