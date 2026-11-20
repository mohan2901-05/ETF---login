package com.etfloans.backend.service;

import com.etfloans.backend.model.Users;
import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.model.UserSessions;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.repository.OtpChallengesRepository;
import com.etfloans.backend.repository.UserSessionsRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

@Service
public class OtpAuthenticationService {

    private final UsersRepository usersRepository;
    private final OtpChallengesRepository otpChallengesRepository;
    private final UserSessionsRepository userSessionsRepository;
    private final OtpDeliveryProvider deliveryProvider;
    private final OtpRateLimiter rateLimiter;

    @Value("${etf.otp.mock-enabled:false}")
    private boolean mockEnabled;

    @Value("${ETF_OTP_MOCK_CODE:}")
    private String mockOtpCode;

    @Value("${ETF_OTP_KEY:}")
    private String otpHmacKey;

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @Value("${ETF_SESSION_EXPIRY_HOURS:720}")
    private long sessionExpiryHours;

    @Value("${etf.otp.expiry-minutes:5}")
    private int expiryMinutes;

    @Value("${etf.demo.enabled:false}")
    private boolean demoEnabled;

    @Value("${etf.demo.api-key:}")
    private String demoApiKey;

    @Value("${etf.demo.android-api-key:}")
    private String androidApiKey;

    @Value("${etf.otp.max-attempts:5}")
    private int maxAttempts;

    @Value("${etf.otp.resend-cooldown-seconds:30}")
    private long resendCooldownSeconds;

    public OtpAuthenticationService(UsersRepository usersRepository,
                                    OtpChallengesRepository otpChallengesRepository,
                                    UserSessionsRepository userSessionsRepository,
                                    OtpDeliveryProvider deliveryProvider,
                                    OtpRateLimiter rateLimiter) {
        this.usersRepository = usersRepository;
        this.otpChallengesRepository = otpChallengesRepository;
        this.userSessionsRepository = userSessionsRepository;
        this.deliveryProvider = deliveryProvider;
        this.rateLimiter = rateLimiter;
    }

    @PostConstruct
    public void init() {
        validateHmacKey();
        validateDemoConfiguration();
    }

    /**
     * Reject unsafe combinations at startup.
     * - Demo mode requires mock-enabled and at least one API key (Vercel proxy or Android)
     * - Production must never have mock-enabled with weak/no HMAC key
     */
    private void validateDemoConfiguration() {
        if (demoEnabled) {
            if (!mockEnabled) {
                throw new IllegalStateException("Demo mode (etf.demo.enabled=true) requires etf.otp.mock-enabled=true");
            }
            boolean hasApiKey = (demoApiKey != null && !demoApiKey.isBlank())
                    || (androidApiKey != null && !androidApiKey.isBlank());
            if (!hasApiKey) {
                throw new IllegalStateException("Demo mode requires at least one API key: etf.demo.api-key (Vercel proxy) or etf.demo.android-api-key (Android APK)");
            }
        }

        // Production safety: if mock is enabled without demo, ensure strong HMAC key
        // (already enforced by validateHmacKey which rejects known weak keys)
    }

    /** Send OTP challenge. */
    public OtpChallenges sendChallenge(String mobileNumber) {
        rateLimiter.checkSend(mobileNumber);

        String otp = useMockOtp() ? mockOtpCode : generateOtp();

        OtpChallenges challenge = new OtpChallenges(
                UUID.randomUUID(),
                mobileNumber,
                hashOtp(otp),
                LocalDateTime.now().plusMinutes(expiryMinutes),
                maxAttempts,
                deliveryProvider.name()
        );
        OtpChallenges saved = otpChallengesRepository.save(challenge);
        deliveryProvider.deliver(mobileNumber, otp);
        return saved;
    }

    /** Verify OTP by challengeId and create a session. */
    @Transactional
    public AuthenticationResult verifyAndAuthenticate(OtpVerificationRequest request,
                                                      LocalDateTime now) {
        if (request.getChallengeId() == null || request.getChallengeId().isBlank()) {
            throw new IllegalArgumentException("Challenge ID is required.");
        }

        rateLimiter.checkVerify(request.getMobileNumber());

        UUID challengeId;
        try {
            challengeId = UUID.fromString(request.getChallengeId());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Invalid challenge ID.");
        }

        OtpChallenges challenge = otpChallengesRepository.findByChallengeId(challengeId)
                .orElseThrow(() -> new IllegalArgumentException("No OTP challenge found."));

        if (challenge.getConsumedAt() != null) {
            throw new IllegalArgumentException("This code has already been used. Request a new one.");
        }
        if (!challenge.getMobileNumber().equals(request.getMobileNumber())) {
            throw new IllegalArgumentException("Mobile number does not match this challenge.");
        }
        if (!challenge.getExpiresAt().isAfter(now)) {
            throw new IllegalArgumentException("OTP has expired. Request a new one.");
        }
        if (challenge.getAttemptCount() >= challenge.getMaxAttempts()) {
            throw new IllegalArgumentException("Maximum verification attempts exceeded. Try again later.");
        }

        String inputHash = hashOtp(request.getOtp());
        if (!inputHash.equals(challenge.getOtpHash())) {
            challenge.setAttemptCount(challenge.getAttemptCount() + 1);
            otpChallengesRepository.save(challenge);
            throw new IllegalArgumentException("Invalid OTP.");
        }

        challenge.setConsumedAt(now);
        otpChallengesRepository.save(challenge);

        boolean[] isNewUser = {false};
        Users user = usersRepository.findByMobileNumber(request.getMobileNumber())
                .orElseGet(() -> {
                    isNewUser[0] = true;
                    return usersRepository.save(new Users(UUID.randomUUID(), request.getMobileNumber()));
                });

        String sessionToken = generateSessionToken();
        String tokenHash = sha256(sessionToken);

        UserSessions session = new UserSessions(
                UUID.randomUUID(),
                user.getId(),
                tokenHash,
                now.plusHours(sessionExpiryHours),
                null,
                null
        );
        userSessionsRepository.save(session);

        return new AuthenticationResult(user, sessionToken, isNewUser[0]);
    }

    /** Resend OTP, enforcing the resend cooldown against the latest challenge. */
    public OtpChallenges resendChallenge(String mobileNumber, LocalDateTime now) {
        OtpChallenges existing = otpChallengesRepository
                .findFirstByMobileNumberOrderByCreatedAtDesc(mobileNumber)
                .orElse(null);

        if (existing != null && existing.getCreatedAt().plusSeconds(resendCooldownSeconds).isAfter(now)) {
            throw new IllegalArgumentException(
                    "Please wait " + resendCooldownSeconds + " seconds before resending.");
        }

        return sendChallenge(mobileNumber);
    }

    /** Return the mock OTP for demo responses, or null when demo mode is off. */
    public String getMockOtp() {
        return useMockOtp() && demoEnabled ? mockOtpCode : null;
    }

    /** True when both mock OTP and demo mode are enabled. */
    public boolean isDemoMode() {
        return mockEnabled && demoEnabled;
    }

    /** Validate bearer token and return the active user session. */
    @Transactional(readOnly = true)
    public UserSessions validateSession(String bearerToken) {
        if (bearerToken == null || !bearerToken.startsWith("Bearer ")) {
            return null;
        }
        String token = bearerToken.substring(7);
        String tokenHash = sha256(token);
        return userSessionsRepository.findByTokenHash(tokenHash)
                .filter(UserSessions::isActive)
                .orElse(null);
    }

    /** Revoke a session (logout). */
    @Transactional
    public void revokeSession(String bearerToken) {
        if (bearerToken == null || !bearerToken.startsWith("Bearer ")) {
            return;
        }
        String token = bearerToken.substring(7);
        String tokenHash = sha256(token);
        userSessionsRepository.findByTokenHash(tokenHash)
                .ifPresent(session -> {
                    session.revoke();
                    userSessionsRepository.save(session);
                });
    }

    // Helper methods

    private boolean useMockOtp() {
        return mockEnabled && mockOtpCode != null && mockOtpCode.length() == 6;
    }

    private String generateOtp() {
        SecureRandom random = new SecureRandom();
        int otp = 100000 + random.nextInt(900000);
        return String.valueOf(otp);
    }

    private String hashOtp(String otp) {
        try {
            Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
            validateHmacKey();
            SecretKeySpec secretKey = new SecretKeySpec(otpHmacKey.getBytes(), "HmacSHA256");
            sha256_HMAC.init(secretKey);
            byte[] hash = sha256_HMAC.doFinal(otp.getBytes());
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private void validateHmacKey() {
        if (otpHmacKey == null || otpHmacKey.isBlank()) {
            throw new IllegalStateException("ETF_OTP_KEY is required but not configured");
        }
        if (otpHmacKey.length() < 32) {
            throw new IllegalStateException("ETF_OTP_KEY must be at least 32 characters");
        }
        if ("ETF-OTP-KEY".equals(otpHmacKey) || "dev-otp-hmac-key-change-in-production".equals(otpHmacKey)
                || "test-otp-hmac-key".equals(otpHmacKey)) {
            throw new IllegalStateException("ETF_OTP_KEY must not be a default/development value");
        }
    }

    private String generateSessionToken() {
        SecureRandom random = new SecureRandom();
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }

    private String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes());
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /** OTP verification request data holder. */
    public static class OtpVerificationRequest {
        private String challengeId;
        private String mobileNumber;
        private String otp;

        public String getChallengeId() {
            return challengeId;
        }

        public void setChallengeId(String challengeId) {
            this.challengeId = challengeId;
        }

        public String getMobileNumber() {
            return mobileNumber;
        }

        public void setMobileNumber(String mobileNumber) {
            this.mobileNumber = mobileNumber;
        }

        public String getOtp() {
            return otp;
        }

        public void setOtp(String otp) {
            this.otp = otp;
        }
    }

    /** Authentication result. */
    public static class AuthenticationResult {
        private Users user;
        private String accessToken;
        private boolean isNewUser;

        public AuthenticationResult(Users user, String accessToken, boolean isNewUser) {
            this.user = user;
            this.accessToken = accessToken;
            this.isNewUser = isNewUser;
        }

        public Users getUser() {
            return user;
        }

        public String getAccessToken() {
            return accessToken;
        }

        public boolean isNewUser() {
            return isNewUser;
        }
    }
}
