import 'package:flutter/material.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/features/onboarding/personal_details_screen.dart';
import 'package:etf_loans/features/onboarding/update_details_screen.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';

/// Presented from authenticated Home. The screens have no public named routes.
class BorrowerFlow extends StatefulWidget {
  const BorrowerFlow({
    required this.accessToken,
    required this.openUpdate,
    this.accountName,
    this.service = const UnavailableBorrowerService(),
    super.key,
  });

  final String accessToken;
  final bool openUpdate;
  final String? accountName;
  final BorrowerService service;

  @override
  State<BorrowerFlow> createState() => _BorrowerFlowState();
}

class _BorrowerFlowState extends State<BorrowerFlow> {
  late Future<BorrowerProfile?> _profile = _loadProfile();

  Future<BorrowerProfile?> _loadProfile() async {
    try {
      return await widget.service.loadProfile(accessToken: widget.accessToken);
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          Navigator.of(context).pop(BorrowerFlowResult.sessionExpired);
        }
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BorrowerProfile?>(
      future: _profile,
      builder: (context, snapshot) {
        final title = widget.openUpdate ? 'Update details' : 'Your details';
        if (snapshot.connectionState != ConnectionState.done) {
          return BorrowerPage(
            title: title,
            description: 'Loading your borrower profile…',
            child: const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading borrower profile',
              ),
            ),
          );
        }

        final unavailable = snapshot.error is BorrowerServiceUnavailable;
        if (snapshot.hasError && !unavailable) {
          return BorrowerPage(
            title: title,
            description: 'We couldn’t load your borrower profile.',
            child: PrimaryButton(
              title: 'Retry',
              onPressed: () {
                setState(() => _profile = _loadProfile());
              },
            ),
          );
        }

        final profile = snapshot.data;
        if (widget.openUpdate || profile != null) {
          return UpdateDetailsScreen(
            service: widget.service,
            accessToken: widget.accessToken,
            profile: profile,
            profileUnavailable: unavailable,
          );
        }

        return PersonalDetailsScreen(
          service: widget.service,
          accessToken: widget.accessToken,
          accountName: widget.accountName,
          profileUnavailable: unavailable,
        );
      },
    );
  }
}
