import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';

class FaceVerificationInstructions extends StatefulWidget {
  const FaceVerificationInstructions({
    required this.openSession,
    required this.onSessionExpired,
    super.key,
  });

  final Future<FaceVerificationSession> Function(bool consent) openSession;
  final VoidCallback onSessionExpired;

  @override
  State<FaceVerificationInstructions> createState() =>
      _FaceVerificationInstructionsState();
}

class _FaceVerificationInstructionsState
    extends State<FaceVerificationInstructions> {
  bool _consent = false;
  bool _cameraOpen = false;

  Future<void> _start() async {
    if (!_consent || _cameraOpen) return;
    final consent = _consent;
    _cameraOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LiveFaceVerificationScreen(
            openSession: () => widget.openSession(consent),
            onSessionExpired: widget.onSessionExpired,
          ),
        ),
      );
    } finally {
      _cameraOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Face verification',
    description: 'Get ready for the camera check.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.light_mode_outlined),
                title: Text('Sit somewhere well lit.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.face_outlined),
                title: Text('Remove glasses and hats.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.center_focus_strong_outlined),
                title: Text('Look straight ahead and follow the prompts.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I agree to use my camera for this identity check.',
          ),
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          title: 'Start face check',
          enabled: _consent,
          onPressed: _start,
        ),
      ],
    ),
  );
}

enum _CameraState {
  opening,
  ready,
  processing,
  denied,
  unavailable,
  interrupted,
}

class LiveFaceVerificationScreen extends StatefulWidget {
  const LiveFaceVerificationScreen({
    required this.openSession,
    required this.onSessionExpired,
    super.key,
  });

  final Future<FaceVerificationSession> Function() openSession;
  final VoidCallback onSessionExpired;

  @override
  State<LiveFaceVerificationScreen> createState() =>
      _LiveFaceVerificationState();
}

class _LiveFaceVerificationState extends State<LiveFaceVerificationScreen>
    with WidgetsBindingObserver {
  _CameraState _state = _CameraState.opening;
  FaceVerificationSession? _session;
  FaceVerificationResult? _result;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _release() {
    _operation++;
    _session?.close();
    _session = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_result == null &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _release();
      setState(() => _state = _CameraState.interrupted);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  Future<void> _open() async {
    _release();
    final operation = _operation;
    setState(() {
      _result = null;
      _state = _CameraState.opening;
    });
    try {
      final session = await widget.openSession();
      if (!mounted || operation != _operation) {
        session.close();
        return;
      }
      setState(() {
        _session = session;
        _state = _CameraState.ready;
      });
    } catch (error) {
      _handleError(error, operation);
    }
  }

  Future<void> _capture() async {
    final session = _session;
    if (session == null || _state != _CameraState.ready) return;
    final operation = _operation;
    setState(() => _state = _CameraState.processing);
    try {
      final result = await session.captureAndVerify();
      if (!mounted || operation != _operation) return;
      _release();
      setState(() => _result = result);
    } catch (error) {
      _handleError(error, operation);
    }
  }

  void _handleError(Object error, int operation) {
    if (!mounted || operation != _operation) return;
    _release();
    setState(
      () => _state = switch (error) {
        VerificationIssue.permissionDenied => _CameraState.denied,
        VerificationIssue.unavailable ||
        InvalidSessionException() => _CameraState.unavailable,
        _ => _CameraState.interrupted,
      },
    );
    if (error is InvalidSessionException) widget.onSessionExpired();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null)
      return FaceVerificationResultScreen(result: result, onRetry: _open);
    final busy =
        _state == _CameraState.opening || _state == _CameraState.processing;
    final message = switch (_state) {
      _CameraState.opening => 'Starting camera',
      _CameraState.ready => 'Position your face inside the oval.',
      _CameraState.processing => 'Waiting for the verification provider',
      _CameraState.denied => 'Camera access was denied. Allow access in your device settings, then try again.',
      _CameraState.unavailable =>
        'The camera or verification provider is currently unavailable.',
      _CameraState.interrupted =>
        'The face check was interrupted. You can try again.',
    };
    return BorrowerPage(
      title: 'Live face check',
      description: _state == _CameraState.ready
          ? message
          : 'Use your front camera for this check.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_state == _CameraState.ready)
            _FacePreview(textureId: _session?.textureId),
          if (_state != _CameraState.ready)
            BorrowerNotice(
              message,
              isError:
                  _state == _CameraState.denied ||
                  _state == _CameraState.interrupted,
            ),
          if (busy && !MediaQuery.disableAnimationsOf(context)) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          if (_state == _CameraState.ready)
            PrimaryButton(title: 'Capture', onPressed: _capture)
          else if (_state == _CameraState.denied ||
              _state == _CameraState.interrupted)
            PrimaryButton(title: 'Try again', onPressed: _open),
        ],
      ),
    );
  }
}

class _FacePreview extends StatelessWidget {
  const _FacePreview({this.textureId});

  final int? textureId;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Camera preview with an oval face guide',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(ThemeConfig.radiusLarge),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (textureId case final id?)
              Texture(textureId: id)
            else
              const ColoredBox(color: ThemeConfig.primaryGreenDeep),
            const FractionallySizedBox(
              heightFactor: 0.8,
              widthFactor: 0.48,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: OvalBorder(
                    side: BorderSide(color: ThemeConfig.onDeep, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FaceVerificationResultScreen extends StatelessWidget {
  const FaceVerificationResultScreen({
    required this.result,
    required this.onRetry,
    super.key,
  });

  final FaceVerificationResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (result.status) {
      VerificationStatus.completed =>
        'The verification provider confirmed your face check.',
      VerificationStatus.failed =>
        'The verification provider could not verify your face check.',
      VerificationStatus.pending =>
        'The verification provider is still reviewing your check.',
      VerificationStatus.unavailable =>
        'The verification provider could not return a result.',
    };
    return BorrowerPage(
      title: 'Face verification result',
      description: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BorrowerNotice(
            result.status.label,
            isError: result.status == VerificationStatus.failed,
          ),
          const SizedBox(height: 20),
          if (result.canRetry &&
              result.status == VerificationStatus.failed) ...[
            PrimaryButton(title: 'Try again', onPressed: onRetry),
            const SizedBox(height: 12),
          ],
          OutlineButton(
            title: 'Back to instructions',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
