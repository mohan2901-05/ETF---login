enum VerificationKind {
  pan('PAN'),
  aadhaar('Aadhaar'),
  face('Face verification'),
  address('Address and work'),
  bank('Bank account');

  const VerificationKind(this.label);
  final String label;
}

enum VerificationStatus {
  pending('Pending'),
  completed('Completed'),
  failed('Failed'),
  unavailable('Unavailable');

  const VerificationStatus(this.label);
  final String label;
}

class VerificationCheck {
  const VerificationCheck(this.status, {this.canStart = false});

  final VerificationStatus status;
  final bool canStart;
}

class FaceVerificationResult {
  const FaceVerificationResult({required this.status, this.canRetry = false});

  final VerificationStatus status;
  final bool canRetry;
}
