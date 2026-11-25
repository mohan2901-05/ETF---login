package com.etfloans.backend.service;

import com.etfloans.backend.model.Users;
import com.etfloans.backend.model.OtpPurpose;
import com.etfloans.backend.model.PasswordGrant;
import com.etfloans.backend.repository.PasswordGrantRepository;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.authentication.BadCredentialsException;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.model.UserSessions;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.repository.OtpChallengesRepository;
import com.etfloans.backend.repository.UserSessionsRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.Duration;
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

    private final Environment environment;
    private final PasswordGrantRepository passwordGrants;

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
                                    OtpRateLimiter rateLimiter,
                                    Environment environment, PasswordGrantRepository passwordGrants) {
        this.usersRepository = usersRepository;
        this.otpChallengesRepository = otpChallengesRepository;
        this.userSessionsRepository = userSessionsRepository;
        this.deliveryProvider = deliveryProvider;
        this.rateLimiter = rateLimiter;
        this.environment = environment;
        this.passwordGrants = passwordGrants;
    }

    @PostConstruct
    public void init() {
        validateHmacKey();
        validateDemoConfiguration();
        dummyHash = passwords.encode(generateSessionToken());
    }

    /**
     * Reject unsafe combinations at startup.
     * - Demo mode requires mock-enabled and at least one API key (Vercel proxy or Android)
     * - Production must never have mock-enabled with weak/no HMAC key
     */
    private void validateDemoConfiguration() {
        if ((mockEnabled || demoEnabled) &&
                !environment.acceptsProfiles(Profiles.of("(local | test) & !prod & !production"))) {
            throw new IllegalStateException("Mock OTP and demo access require a local or test profile");
        }
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

    private static final String SUPPRESSED = "suppressed";
    private static final String MOCK_PROVIDER = "mock";
    private static final int GRANT_MINUTES = 5;
    private final BCryptPasswordEncoder passwords = new BCryptPasswordEncoder(12);
    private String dummyHash;

    public OtpChallenges sendChallenge(String mobileNumber) {
        rateLimiter.checkSend(mobileNumber);
        Users user = usersRepository.findByMobileNumber(mobileNumber).orElse(null);
        return issue(mobileNumber, OtpPurpose.LEGACY_LOGIN, fingerprint(user),
                user == null || user.isActive() && user.getPasswordHash() == null,
                LocalDateTime.now().plusMinutes(expiryMinutes));
    }

    public OtpChallenges startPasswordFlow(OtpPurpose purpose, String mobileNumber, String password) {
        rateLimiter.checkSend(mobileNumber);
        Users user = usersRepository.findByMobileNumber(mobileNumber).orElse(null);
        boolean active = user != null && user.isActive();
        boolean hasPassword = user != null && user.getPasswordHash() != null;
        boolean deliver = switch (purpose) {
            case PASSWORD_LOGIN -> {
                boolean validInput = validLoginInput(password);
                String input = validInput ? password : "";
                boolean matches = passwords.matches(input, active && hasPassword ? user.getPasswordHash() : dummyHash);
                if (!active || !hasPassword || !matches || !validInput) {
                    throw new BadCredentialsException("Invalid mobile number or password. Please try again.");
                }
                yield true;
            }
            case REGISTRATION -> user == null || active && !hasPassword;
            case RECOVERY -> active && hasPassword;
            default -> throw new IllegalArgumentException("Invalid authentication purpose.");
        };
        return issue(mobileNumber, purpose, fingerprint(user), deliver,
                LocalDateTime.now().plusMinutes(expiryMinutes));
    }

    private OtpChallenges issue(String mobile, OtpPurpose purpose, String fingerprint, boolean deliver,
                                LocalDateTime expiresAt) {
        deliver = deliver && (!MOCK_PROVIDER.equals(deliveryProvider.name()) || useMockOtp());
        String otp = deliver && useMockOtp() ? mockOtpCode : generateOtp();
        OtpChallenges challenge = new OtpChallenges(UUID.randomUUID(), mobile, hashOtp(otp),
                expiresAt, maxAttempts,
                deliver ? deliveryProvider.name() : SUPPRESSED);
        challenge.bindTo(purpose, fingerprint);
        OtpChallenges saved = otpChallengesRepository.save(challenge);
        if (deliver) deliveryProvider.deliver(mobile, otp);
        return saved;
    }

    @Transactional
    public OtpChallenges resendChallenge(OtpPurpose purpose, String mobile, String id) {
        rateLimiter.checkSend(mobile);
        OtpChallenges previous = lockChallenge(id, mobile, purpose);
        LocalDateTime now = LocalDateTime.now();
        if (previous.getConsumedAt() != null) {
            throw new IllegalArgumentException("Request a new verification code.");
        }
        if (purpose == OtpPurpose.PASSWORD_LOGIN && !previous.getExpiresAt().isAfter(now)) {
            throw new IllegalArgumentException("Sign in again to request a verification code.");
        }
        if (previous.getCreatedAt().plusSeconds(resendCooldownSeconds).isAfter(now)) {
            throw new IllegalArgumentException("Please wait before resending.");
        }
        previous.setConsumedAt(now);
        Users user = usersRepository.findByMobileNumber(mobile).orElse(null);
        return issue(mobile, purpose, previous.getCredentialFingerprint(),
                allowsVerification(previous) &&
                        Objects.equals(previous.getCredentialFingerprint(), fingerprint(user)) &&
                        (user == null || user.isActive()),
                purpose == OtpPurpose.PASSWORD_LOGIN ? previous.getExpiresAt() : now.plusMinutes(expiryMinutes));
    }

    @Transactional(noRollbackFor = InvalidOtpException.class)
    public AuthenticationResult verifyAndAuthenticate(OtpVerificationRequest request) {
        return authenticate(request, OtpPurpose.LEGACY_LOGIN);
    }

    @Transactional(noRollbackFor = InvalidOtpException.class)
    public AuthenticationResult verifyPasswordSignIn(OtpVerificationRequest request) {
        return authenticate(request, OtpPurpose.PASSWORD_LOGIN);
    }

    private AuthenticationResult authenticate(OtpVerificationRequest request, OtpPurpose purpose) {
        OtpChallenges challenge = verifyChallenge(request, purpose);
        Users user = usersRepository.lockByMobileNumber(request.getMobileNumber()).orElse(null);
        if (!matchesCredential(challenge, user)
                || purpose == OtpPurpose.PASSWORD_LOGIN && user == null) {
            throw new IllegalArgumentException("Authentication could not be completed.");
        }
        LocalDateTime now = consumeChallenge(challenge);
        boolean isNew = user == null;
        if (isNew) {
            user = usersRepository.save(new Users(UUID.randomUUID(), request.getMobileNumber()));
        }
        String sessionToken = generateSessionToken();
        userSessionsRepository.save(new UserSessions(UUID.randomUUID(), user.getId(), sha256(sessionToken),
                now.plusHours(sessionExpiryHours), null, null));
        return new AuthenticationResult(user, sessionToken, isNew);
    }

    @Transactional(noRollbackFor = InvalidOtpException.class)
    public String verifyForPasswordGrant(OtpVerificationRequest request, OtpPurpose purpose) {
        requireGrantPurpose(purpose);
        OtpChallenges challenge = verifyChallenge(request, purpose);
        Users user = usersRepository.lockByMobileNumber(request.getMobileNumber()).orElse(null);
        if (!matchesCredential(challenge, user) || purpose == OtpPurpose.RECOVERY && user == null) {
            throw new IllegalArgumentException("Authentication could not be completed.");
        }
        LocalDateTime now = consumeChallenge(challenge);
        String token = generateSessionToken();
        passwordGrants.save(new PasswordGrant(sha256(token), challenge, now.plusMinutes(GRANT_MINUTES)));
        return token;
    }

    @Transactional
    public void completePasswordFlow(OtpPurpose purpose, String token, String password) {
        requireGrantPurpose(purpose);
        if (password == null || password.codePointCount(0, password.length()) < 12 || !validLoginInput(password)) {
            throw new IllegalArgumentException("Use at least 12 characters and at most 72 UTF-8 bytes.");
        }
        if (token == null || token.length() != 44) {
            throw invalidGrant();
        }
        PasswordGrant grant = passwordGrants.lockByHash(sha256(token))
                .orElseThrow(OtpAuthenticationService::invalidGrant);
        if (!grant.isUsableFor(purpose, LocalDateTime.now())) {
            throw invalidGrant();
        }
        Users user = usersRepository.lockByMobileNumber(grant.getMobileNumber()).orElse(null);
        LocalDateTime now = LocalDateTime.now();
        if (!grant.isUsableFor(purpose, now)
                || !Objects.equals(grant.getCredentialFingerprint(), fingerprint(user)) ||
                (user != null && !user.isActive()) || (purpose == OtpPurpose.RECOVERY && user == null)) {
            throw invalidGrant();
        }
        if (user == null) {
            user = new Users(UUID.randomUUID(), grant.getMobileNumber());
        }
        user.setPasswordHash(passwords.encode(password));
        usersRepository.save(user);
        userSessionsRepository.revokeAllForUser(user.getId(), now);
        grant.consume(now);
    }

    private static IllegalArgumentException invalidGrant() {
        return new IllegalArgumentException("Verification expired or invalid. Request a new code.");
    }

    private static void requireGrantPurpose(OtpPurpose purpose) {
        if (purpose != OtpPurpose.REGISTRATION && purpose != OtpPurpose.RECOVERY) {
            throw invalidGrant();
        }
    }

    private boolean matchesCredential(OtpChallenges challenge, Users user) {
        return (user == null || user.isActive())
                && Objects.equals(challenge.getCredentialFingerprint(), fingerprint(user))
                && (challenge.getPurpose() != OtpPurpose.LEGACY_LOGIN || fingerprint(user) == null);
    }

    private String fingerprint(Users user) {
        return user == null || user.getPasswordHash() == null ? null : sha256(user.getPasswordHash());
    }

    private static boolean validLoginInput(String password) {
        return password != null && !password.isBlank() && password.length() <= 72 &&
                password.getBytes(StandardCharsets.UTF_8).length <= 72;
    }

    private OtpChallenges verifyChallenge(OtpVerificationRequest request, OtpPurpose purpose) {
        rateLimiter.checkVerify(request.getMobileNumber());
        OtpChallenges challenge = lockChallenge(request.getChallengeId(), request.getMobileNumber(), purpose);
        if (challenge.getConsumedAt() != null) {
            throw new IllegalArgumentException("This code has already been used. Request a new one.");
        }
        requireUnexpired(challenge, LocalDateTime.now());
        if (challenge.getAttemptCount() >= challenge.getMaxAttempts()) {
            throw new IllegalArgumentException("Maximum verification attempts exceeded. Try again later.");
        }
        String inputHash = hashOtp(request.getOtp());
        if (!MessageDigest.isEqual(HexFormat.of().parseHex(inputHash),
                HexFormat.of().parseHex(challenge.getOtpHash())) || !allowsVerification(challenge)) {
            challenge.setAttemptCount(challenge.getAttemptCount() + 1);
            throw new InvalidOtpException();
        }
        return challenge;
    }

    private boolean allowsVerification(OtpChallenges challenge) {
        String provider = challenge.getDeliveryProvider();
        return !SUPPRESSED.equals(provider) && (!MOCK_PROVIDER.equals(provider) || useMockOtp());
    }

    private static LocalDateTime consumeChallenge(OtpChallenges challenge) {
        LocalDateTime now = LocalDateTime.now();
        requireUnexpired(challenge, now);
        challenge.setConsumedAt(now);
        return now;
    }

    private static void requireUnexpired(OtpChallenges challenge, LocalDateTime now) {
        if (!challenge.getExpiresAt().isAfter(now)) {
            throw new IllegalArgumentException("OTP has expired. Request a new one.");
        }
    }

    private OtpChallenges lockChallenge(String id, String mobile, OtpPurpose purpose) {
        if (id == null || id.isBlank()) {
            throw new IllegalArgumentException("Challenge ID is required.");
        }
        UUID uuid;
        try {
            uuid = UUID.fromString(id);
            if (!uuid.toString().equalsIgnoreCase(id)) {
                throw new IllegalArgumentException();
            }
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Invalid challenge ID.");
        }
        return otpChallengesRepository.lockByChallengeId(uuid)
                .filter(challenge -> challenge.getMobileNumber().equals(mobile) && challenge.getPurpose() == purpose)
                .orElseThrow(InvalidOtpException::new);
    }


    public int challengeExpirySeconds(OtpChallenges challenge) {
        long milliseconds = Duration.between(challenge.getCreatedAt(), challenge.getExpiresAt()).toMillis();
        return Math.toIntExact(Math.max(0, (milliseconds + 999) / 1000));
    }

    public int resendDelaySeconds() {
        return Math.toIntExact(resendCooldownSeconds);
    }

    public int sessionExpirySeconds() {
        return Math.toIntExact(Duration.ofHours(sessionExpiryHours).toSeconds());
    }

    /** Return the mock OTP only when local or test configuration enables it. */
    public String getMockOtp() {
        return useMockOtp() ? mockOtpCode : null;
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
                .filter(session -> usersRepository.findById(session.getUserId())
                        .filter(Users::isActive).isPresent())
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

    private static final class InvalidOtpException extends IllegalArgumentException {
        private InvalidOtpException() {
            super("Invalid OTP.");
        }
    }

    // Helper methods

    private boolean useMockOtp() {
        return mockEnabled && mockOtpCode != null && mockOtpCode.matches("[0-9]{6}");
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
            SecretKeySpec secretKey = new SecretKeySpec(effectiveOtpKey().getBytes(StandardCharsets.UTF_8),
                    "HmacSHA256");
            sha256_HMAC.init(secretKey);
            byte[] hash = sha256_HMAC.doFinal(otp.getBytes());
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private void validateHmacKey() {
        String otpHmacKey = effectiveOtpKey();
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

    private String effectiveOtpKey() {
        return environment.acceptsProfiles(Profiles.of("local | test"))
                ? environment.getProperty("etf.otp.development-key", "") : otpHmacKey;
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
