package com.etfloans.backend.controller;

import com.etfloans.backend.dto.*;
import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.model.OtpPurpose;
import com.etfloans.backend.model.Users;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.service.OtpAuthenticationService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/auth")
public class AuthenticationController {

    private static final Pattern MOBILE_NUMBER = Pattern.compile("^[6-9]\\d{9}$");
    private static final Pattern OTP_CODE = Pattern.compile("^\\d{6}$");

    @Autowired
    private OtpAuthenticationService otpAuthService;

    @Autowired
    private UsersRepository usersRepository;

    @PostMapping("/otp/send")
    public ResponseEntity<OtpSendResponse> sendOtp(@Valid @RequestBody OtpSendRequest request) {
        validateMobileNumber(request.getMobileNumber());
        return sendResponse(otpAuthService.sendChallenge(request.getMobileNumber()));
    }

    private ResponseEntity<OtpSendResponse> sendResponse(OtpChallenges challenge) {
        OtpSendResponse response = new OtpSendResponse(
                true,
                "Verification code requested.",
                challenge.getChallengeId(),
                otpAuthService.challengeExpirySeconds(challenge),
                otpAuthService.resendDelaySeconds()
        );

        // The service allows mock OTP output only in local and test profiles.
        String mockOtp = otpAuthService.getMockOtp();
        if (mockOtp != null) {
            response.setDevelopmentOtp(mockOtp);
        }

        return ResponseEntity.ok().header("Cache-Control", "no-store").body(response);
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<OtpVerifyResponse> verifyOtp(@Valid @RequestBody OtpVerificationRequest request) {
        return authenticated(otpAuthService.verifyAndAuthenticate(verification(request)));
    }

    @PostMapping("/otp/resend")
    public ResponseEntity<OtpSendResponse> resendOtp(@RequestBody ResendRequest request) {
        return resend(OtpPurpose.LEGACY_LOGIN, request);
    }

    @PostMapping("/password/{flow}/start")
    public ResponseEntity<OtpSendResponse> startPassword(@PathVariable String flow, @RequestBody StartRequest request) {
        validateMobileNumber(request.mobileNumber());
        return sendResponse(otpAuthService.startPasswordFlow(purpose(flow), request.mobileNumber(), request.password()));
    }

    @PostMapping("/password/{flow}/resend")
    public ResponseEntity<OtpSendResponse> resendPassword(@PathVariable String flow, @RequestBody ResendRequest request) {
        return resend(purpose(flow), request);
    }

    @PostMapping("/password/{flow}/verify")
    public ResponseEntity<?> verifyPassword(@PathVariable String flow,
                                             @Valid @RequestBody OtpVerificationRequest request) {
        var purpose = purpose(flow);
        var verification = verification(request);
        if (purpose == OtpPurpose.PASSWORD_LOGIN) {
            return authenticated(otpAuthService.verifyPasswordSignIn(verification));
        }
        String grant = otpAuthService.verifyForPasswordGrant(verification, purpose);
        return ResponseEntity.ok().header("Cache-Control", "no-store").body(new GrantResponse(grant));
    }

    @PostMapping("/password/{flow}/complete")
    public ResponseEntity<Void> completePassword(@PathVariable String flow, @RequestBody CompleteRequest request) {
        otpAuthService.completePasswordFlow(purpose(flow), request.grantToken(), request.password());
        return ResponseEntity.noContent().build();
    }

    private ResponseEntity<OtpSendResponse> resend(OtpPurpose purpose, ResendRequest request) {
        validateMobileNumber(request.mobileNumber());
        return sendResponse(otpAuthService.resendChallenge(
                purpose, request.mobileNumber(), request.challengeId()));
    }

    private static OtpPurpose purpose(String flow) {
        return switch (flow) {
            case "login" -> OtpPurpose.PASSWORD_LOGIN;
            case "registration" -> OtpPurpose.REGISTRATION;
            case "recovery" -> OtpPurpose.RECOVERY;
            default -> throw new IllegalArgumentException("Invalid authentication purpose.");
        };
    }

    public record StartRequest(String mobileNumber, String password) {
        @Override public String toString() { return "StartRequest[redacted]"; }
    }
    public record ResendRequest(String mobileNumber, String challengeId) {
        @Override public String toString() { return "ResendRequest[redacted]"; }
    }
    public record CompleteRequest(String grantToken, String password) {
        @Override public String toString() { return "CompleteRequest[redacted]"; }
    }
    public record GrantResponse(String grantToken) {
        @Override public String toString() { return "GrantResponse[redacted]"; }
    }

    private OtpAuthenticationService.OtpVerificationRequest verification(OtpVerificationRequest request) {
        validateMobileNumber(request.getMobileNumber());
        if (request.getOtp() == null || !OTP_CODE.matcher(request.getOtp()).matches()) {
            throw new IllegalArgumentException("OTP must be 6 digits.");
        }

        OtpAuthenticationService.OtpVerificationRequest serviceRequest =
                new OtpAuthenticationService.OtpVerificationRequest();
        serviceRequest.setChallengeId(request.getChallengeId());
        serviceRequest.setMobileNumber(request.getMobileNumber());
        serviceRequest.setOtp(request.getOtp());

        return serviceRequest;
    }

    private ResponseEntity<OtpVerifyResponse> authenticated(OtpAuthenticationService.AuthenticationResult result) {
        Users user = result.getUser();
        VerifyUser verifyUser = new VerifyUser(
                user.getId(),
                user.getMobileNumber(),
                user.getFullName(),
                result.isNewUser()
        );

        OtpVerifyResponse response = new OtpVerifyResponse(
                true,
                "Authentication successful.",
                result.getAccessToken(),
                "Bearer",
                otpAuthService.sessionExpirySeconds(),
                verifyUser
        );

        return ResponseEntity.ok().header("Cache-Control", "no-store").body(response);
    }

    @PostMapping("/logout")
    public ResponseEntity<ErrorResponse> logout(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            otpAuthService.revokeSession(authHeader);
        }
        return ResponseEntity.ok(new ErrorResponse("Logged out successfully"));
    }

    private void validateMobileNumber(String mobileNumber) {
        if (mobileNumber == null || !MOBILE_NUMBER.matcher(mobileNumber).matches()) {
            throw new IllegalArgumentException("Enter a valid 10-digit mobile number");
        }
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ErrorResponse> handleInvalidCredentials(BadCredentialsException exception) {
        return ResponseEntity.status(401)
                .header("Cache-Control", "no-store")
                .body(new ErrorResponse(exception.getMessage()));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleConcurrentAccountCreation() {
        return ResponseEntity.status(409)
                .body(new ErrorResponse("Authentication could not be completed. Request a new code."));
    }

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal UUID userId) {
        Optional<Users> userOpt = usersRepository.findById(userId).filter(Users::isActive);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(401)
                    .body(new ErrorResponse("Authentication required"));
        }

        Users user = userOpt.get();
        VerifyUser verifyUser = new VerifyUser(
                user.getId(),
                user.getMobileNumber(),
                user.getFullName(),
                false
        );

        return ResponseEntity.ok(verifyUser);
    }
}
