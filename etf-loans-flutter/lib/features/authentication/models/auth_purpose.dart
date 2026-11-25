enum AuthPurpose {
  legacyLogin(''),
  passwordLogin('login'),
  registration('registration'),
  recovery('recovery');

  const AuthPurpose(this.path);
  final String path;

  bool get issuesGrant => this == registration || this == recovery;

  String endpoint(String action) => '/api/auth/password/$path/$action';
}
