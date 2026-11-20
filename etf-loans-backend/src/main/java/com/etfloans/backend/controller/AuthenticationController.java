package com.etfloans.backend.controller;

import com.etfloans.backend.dto.*;
import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.model.Users;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.service.OtpAuthenticationService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Optional;
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
        OtpChallenges challenge = otpAuthService.sendChallenge(request.getMobileNumber());

        OtpSendResponse response = new OtpSendResponse(
                true,
                "Verification code requested.",
                challenge.getChallengeId(),
                300,
                30
        );

        // Include development OTP only in local profile
        String mockOtp = otpAuthService.getMockOtp();
        if (mockOtp != null) {
            response.setDevelopmentOtp(mockOtp);
        }

        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<OtpVerifyResponse> verifyOtp(@Valid @RequestBody OtpVerificationRequest request) {
        validateMobileNumber(request.getMobileNumber());
        if (request.getOtp() == null || !OTP_CODE.matcher(request.getOtp()).matches()) {
            throw new IllegalArgumentException("OTP must be 6 digits.");
        }

        OtpAuthenticationService.OtpVerificationRequest serviceRequest =
                new OtpAuthenticationService.OtpVerificationRequest();
        serviceRequest.setChallengeId(request.getChallengeId());
        serviceRequest.setMobileNumber(request.getMobileNumber());
        serviceRequest.setOtp(request.getOtp());

        OtpAuthenticationService.AuthenticationResult result =
                otpAuthService.verifyAndAuthenticate(serviceRequest, LocalDateTime.now());

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
                2592000, // 30 days
                verifyUser
        );

        return ResponseEntity.ok(response);
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

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(401)
                    .body(new ErrorResponse("Authentication required"));
        }

        // Validate session using service
        var session = otpAuthService.validateSession(authHeader);
        if (session == null) {
            return ResponseEntity.status(401)
                    .body(new ErrorResponse("Invalid or expired token"));
        }

        // Find user by session userId
        Optional<Users> userOpt = usersRepository.findById(session.getUserId());
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(404)
                    .body(new ErrorResponse("User not found"));
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