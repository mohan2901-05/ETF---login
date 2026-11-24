// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MobileNumberRequest _$MobileNumberRequestFromJson(Map<String, dynamic> json) =>
    MobileNumberRequest(mobileNumber: json['mobileNumber'] as String);

Map<String, dynamic> _$MobileNumberRequestToJson(
  MobileNumberRequest instance,
) => <String, dynamic>{'mobileNumber': instance.mobileNumber};

OtpVerificationRequest _$OtpVerificationRequestFromJson(
  Map<String, dynamic> json,
) => OtpVerificationRequest(
  challengeId: json['challengeId'] as String,
  mobileNumber: json['mobileNumber'] as String,
  otp: json['otp'] as String,
);

Map<String, dynamic> _$OtpVerificationRequestToJson(
  OtpVerificationRequest instance,
) => <String, dynamic>{
  'challengeId': instance.challengeId,
  'mobileNumber': instance.mobileNumber,
  'otp': instance.otp,
};

OtpSendResponse _$OtpSendResponseFromJson(Map<String, dynamic> json) =>
    OtpSendResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      challengeId: json['challengeId'] as String?,
      expirySeconds: (json['expirySeconds'] as num?)?.toInt(),
      resendAfterSeconds: (json['resendAfterSeconds'] as num?)?.toInt(),
      developmentOtp: json['developmentOtp'] as String?,
    );

Map<String, dynamic> _$OtpSendResponseToJson(OtpSendResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'challengeId': instance.challengeId,
      'expirySeconds': instance.expirySeconds,
      'resendAfterSeconds': instance.resendAfterSeconds,
      'developmentOtp': instance.developmentOtp,
    };

OtpVerifyResponse _$OtpVerifyResponseFromJson(Map<String, dynamic> json) =>
    OtpVerifyResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      accessToken: json['accessToken'] as String?,
      tokenType: json['tokenType'] as String?,
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt(),
      user: json['user'] == null
          ? null
          : VerifyUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OtpVerifyResponseToJson(OtpVerifyResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'accessToken': instance.accessToken,
      'tokenType': instance.tokenType,
      'expiresInSeconds': instance.expiresInSeconds,
      'user': instance.user?.toJson(),
    };

VerifyUser _$VerifyUserFromJson(Map<String, dynamic> json) => VerifyUser(
  id: json['id'] as String,
  mobileNumber: json['mobileNumber'] as String,
  name: json['name'] as String?,
  isNewUser: json['isNewUser'] as bool?,
);

Map<String, dynamic> _$VerifyUserToJson(VerifyUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mobileNumber': instance.mobileNumber,
      'name': instance.name,
      'isNewUser': instance.isNewUser,
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: json['id'] as String,
  mobileNumber: json['mobileNumber'] as String,
  name: json['name'] as String?,
  email: json['email'] as String?,
  createdAt: json['createdAt'] as String?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mobileNumber': instance.mobileNumber,
      'name': instance.name,
      'email': instance.email,
      'createdAt': instance.createdAt,
    };
