import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class MobileNumberRequest {
  final String mobileNumber;

  MobileNumberRequest({
    required this.mobileNumber,
  });

  factory MobileNumberRequest.fromJson(Map<String, dynamic> json) =>
      _$MobileNumberRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MobileNumberRequestToJson(this);
}

@JsonSerializable()
class OtpVerificationRequest {
  final String challengeId;
  final String mobileNumber;
  final String otp;

  OtpVerificationRequest({
    required this.challengeId,
    required this.mobileNumber,
    required this.otp,
  });

  factory OtpVerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpVerificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OtpVerificationRequestToJson(this);
}

@JsonSerializable()
class OtpSendResponse {
  final bool success;
  final String? message;
  final String? challengeId;
  final int? expirySeconds;
  final int? resendAfterSeconds;
  final String? developmentOtp;

  OtpSendResponse({
    required this.success,
    this.message,
    this.challengeId,
    this.expirySeconds,
    this.resendAfterSeconds,
    this.developmentOtp,
  });

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpSendResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSendResponseToJson(this);
}

@JsonSerializable()
class OtpVerifyResponse {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? tokenType;
  final int? expiresInSeconds;
  final VerifyUser? user;

  OtpVerifyResponse({
    required this.success,
    this.message,
    this.accessToken,
    this.tokenType,
    this.expiresInSeconds,
    this.user,
  });

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpVerifyResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OtpVerifyResponseToJson(this);
}

@JsonSerializable()
class VerifyUser {
  final String id;
  final String mobileNumber;
  final String? name;
  final bool isNewUser;

  VerifyUser({
    required this.id,
    required this.mobileNumber,
    this.name,
    required this.isNewUser,
  });

  factory VerifyUser.fromJson(Map<String, dynamic> json) =>
      _$VerifyUserFromJson(json);

  Map<String, dynamic> toJson() => _$VerifyUserToJson(this);
}

@JsonSerializable()
class UserProfile {
  final String id;
  final String mobileNumber;
  final String name;
  final String? email;
  final String? createdAt;

  UserProfile({
    required this.id,
    required this.mobileNumber,
    required this.name,
    this.email,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}