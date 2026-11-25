package com.etfloans.backend;

import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.repository.OtpChallengesRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.UUID;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class OtpFlowTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private OtpChallengesRepository challenges;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private TransactionTemplate transactions;
    @Autowired
    private jakarta.persistence.EntityManager entities;

    private static final String TEST_PASSWORD = "fixture-only-password";

    @Test
    void earlyResendReportsTheRemainingCooldown() throws Exception {
        String mobile = "9100000024";
        String id = send(mobile);
        var response = authRequest("/otp/resend", Map.of("mobileNumber", mobile, "challengeId", id)).getResponse();
        assertEquals(429, response.getStatus());
        long seconds = Long.parseLong(response.getHeader("Retry-After"));
        assertTrue(seconds > 0 && seconds <= 30);
        assertEquals("Too many requests. Try again in " + seconds + " seconds.",
                objectMapper.readTree(response.getContentAsString()).path("message").asText());
    }

    @Test
    void incorrectAttemptPersistsAndConcurrentOtpCanSucceedOnlyOnce() throws Exception {
        String mobile = "9100000001";
        String id = send(mobile);
        passwordRequest("/otp/verify", Map.of("challengeId", id, "mobileNumber", mobile, "otp", "000000"), 400);
        org.junit.jupiter.api.Assertions.assertEquals(1,
                challenges.findById(UUID.fromString(id)).orElseThrow().getAttemptCount());
        var result = race(() -> authRequest("/otp/verify",
                Map.of("challengeId", id, "mobileNumber", mobile, "otp", "123456"))
                .getResponse().getStatus());
        org.junit.jupiter.api.Assertions.assertEquals(java.util.List.of(200, 400), result);
    }

    @Test
    void passwordRegistrationCannotUseLegacyOtpOrReplayGrant() throws Exception {
        String mobile = "9100000002";
        String id = passwordRequest("/password/registration/start", Map.of("mobileNumber", mobile), 200)
                .path("challengeId").asText();
        var verification = Map.of("challengeId", id, "mobileNumber", mobile, "otp", "123456");
        passwordRequest("/otp/verify", verification, 400);
        String grant = passwordRequest("/password/registration/verify", verification, 200).path("grantToken").asText();
        var completion = Map.of("grantToken", grant, "password", TEST_PASSWORD);
        passwordRequest("/password/recovery/complete", completion, 400);
        passwordRequest("/password/registration/complete",
                Map.of("grantToken", grant, "password", "é".repeat(37)), 400);
        var outcomes = race(() -> authRequest("/password/registration/complete", completion).getResponse().getStatus());
        org.junit.jupiter.api.Assertions.assertEquals(java.util.List.of(204, 400), outcomes);

        String legacyId = send(mobile);
        passwordRequest("/otp/verify",
                Map.of("challengeId", legacyId, "mobileNumber", mobile, "otp", "123456"), 400);
        String passwordId = passwordRequest("/password/login/start",
                Map.of("mobileNumber", mobile, "password", TEST_PASSWORD), 200).path("challengeId").asText();
        var session = passwordRequest("/password/login/verify",
                Map.of("challengeId", passwordId, "mobileNumber", mobile, "otp", "123456"), 200);
        org.junit.jupiter.api.Assertions.assertFalse(session.path("accessToken").asText().isEmpty());
    }

    @Test
    void resendingSupersedesTheOldChallenge() throws Exception {
        String mobile = "9100000003";
        String oldId = send(mobile);
        makeResendEligible(oldId);
        String newId = passwordRequest("/otp/resend", Map.of("mobileNumber", mobile, "challengeId", oldId), 200)
                .path("challengeId").asText();
        passwordRequest("/otp/verify", Map.of("challengeId", oldId, "mobileNumber", mobile, "otp", "123456"), 400);
        passwordRequest("/otp/verify", Map.of("challengeId", newId, "mobileNumber", mobile, "otp", "123456"), 200);
    }

    @Test
    void recoveryRevokesSessionsAndDoesNotIssueToken() throws Exception {
        String mobile = "9100000004";
        var user = new com.etfloans.backend.model.Users(UUID.randomUUID(), mobile);
        user.setPasswordHash(new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder(12).encode(TEST_PASSWORD));
        users.save(user);
        String login = passwordRequest("/password/login/start",
                Map.of("mobileNumber", mobile, "password", TEST_PASSWORD), 200).path("challengeId").asText();
        String token = passwordRequest("/password/login/verify",
                Map.of("challengeId", login, "mobileNumber", mobile, "otp", "123456"), 200).path("accessToken").asText();
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        String recovery = passwordRequest("/password/recovery/start", Map.of("mobileNumber", mobile), 200)
                .path("challengeId").asText();
        var verified = passwordRequest("/password/recovery/verify",
                Map.of("challengeId", recovery, "mobileNumber", mobile, "otp", "123456"), 200);
        org.junit.jupiter.api.Assertions.assertFalse(verified.has("accessToken"));
        passwordRequest("/password/recovery/complete",
                Map.of("grantToken", verified.path("grantToken").asText(), "password", "updated-fixture-password"), 204);
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
        passwordRequest("/password/login/start",
                Map.of("mobileNumber", mobile, "password", TEST_PASSWORD), 401);
    }

    @Test
    void inactiveUsersCannotSignInOrContinueAnExistingSession() throws Exception {
        String mobile = "9100000005";
        String id = send(mobile);
        String token = passwordRequest("/otp/verify",
                Map.of("challengeId", id, "mobileNumber", mobile, "otp", "123456"), 200).path("accessToken").asText();
        var user = users.findByMobileNumber(mobile).orElseThrow();
        user.setActive(false);
        users.save(user);
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
        String blocked = send(mobile);
        passwordRequest("/otp/verify",
                Map.of("challengeId", blocked, "mobileNumber", mobile, "otp", "123456"), 400);
    }

    private java.util.List<Integer> race(Callable<Integer> request) throws Exception {
        var executor = Executors.newFixedThreadPool(2);
        try {
            var results = executor.invokeAll(java.util.List.of(request, request), 15, TimeUnit.SECONDS);
            var first = results.get(0).get();
            var second = results.get(1).get();
            return java.util.List.of(Math.min(first, second), Math.max(first, second));
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void bcryptAcceptsExactly72Utf8BytesAndRejectsAnOverlongLogin() throws Exception {
        String mobile = "9100000006";
        String grant = grant("registration", mobile);
        String password = "é".repeat(36);
        passwordRequest("/password/registration/complete", Map.of("grantToken", grant, "password", password + "a"), 400);
        passwordRequest("/password/registration/complete", Map.of("grantToken", grant, "password", password), 204);
        passwordRequest("/password/login/start",
                Map.of("mobileNumber", mobile, "password", password + "a"), 401);
        passwordRequest("/password/login/verify", otp(mobile, startLogin(mobile, password)), 200);
    }

    @Test
    void invalidPasswordLoginStartsHaveAnIdenticalResponseAndCreateNoChallenge() throws Exception {
        String existing = "9100000020";
        String unknown = "9100000021";
        String passwordless = "9100000022";
        String inactive = "9100000023";
        createPasswordUser(existing);
        createPasswordUser(inactive);
        var inactiveUser = users.findByMobileNumber(inactive).orElseThrow();
        inactiveUser.setActive(false);
        users.save(inactiveUser);
        users.save(new com.etfloans.backend.model.Users(UUID.randomUUID(), passwordless));
        var failures = Map.of(existing, "fixture-wrong-password", unknown, TEST_PASSWORD,
                passwordless, TEST_PASSWORD, inactive, TEST_PASSWORD);
        JsonNode expected = objectMapper.readTree("""
                {"success":false,"message":"Invalid mobile number or password. Please try again."}
                """);
        for (var failure : failures.entrySet()) {
            var response = passwordRequest("/password/login/start",
                    Map.of("mobileNumber", failure.getKey(), "password", failure.getValue()), 401);
            assertEquals(expected, response);
            assertTrue(challenges.findFirstByMobileNumberOrderByCreatedAtDesc(failure.getKey()).isEmpty());
        }
        for (int attempt = 0; attempt < 2; attempt++) {
            passwordRequest("/password/login/start",
                    Map.of("mobileNumber", unknown, "password", TEST_PASSWORD), 401);
        }
        passwordRequest("/password/login/start",
                Map.of("mobileNumber", unknown, "password", TEST_PASSWORD), 429);
        passwordRequest("/password/login/verify", otp(existing, startLogin(existing, TEST_PASSWORD)), 200);
    }

    @Test
    void expiredGrantCannotChangePassword() throws Exception {
        String mobile = "9100000007";
        String grant = grant("registration", mobile);
        jdbc.update("update password_grants set expires_at = ? where mobile_number = ?",
                LocalDateTime.now().minusMinutes(1), mobile);
        passwordRequest("/password/registration/complete", Map.of("grantToken", grant, "password", TEST_PASSWORD), 400);
        assertTrue(users.findByMobileNumber(mobile).isEmpty());
    }

    @Test
    void passwordChangeAndSessionRevocationRollBackWithGrantConsumption() throws Exception {
        String mobile = "9100000008";
        String originalHash = createPasswordUser(mobile);
        String token = passwordRequest("/password/login/verify", otp(mobile, startLogin(mobile, TEST_PASSWORD)), 200)
                .path("accessToken").asText();
        String grant = grant("recovery", mobile);
        var recovery = com.etfloans.backend.model.OtpPurpose.RECOVERY;
        transactions.executeWithoutResult(tx -> {
            otpService.completePasswordFlow(recovery, grant, "fixture-updated-password");
            entities.flush();
            assertEquals(1, jdbc.queryForObject("select count(*) from password_grants where mobile_number=? and consumed_at is not null",
                    Integer.class, mobile));
            tx.setRollbackOnly();
        });
        assertEquals(originalHash, users.findByMobileNumber(mobile).orElseThrow().getPasswordHash());
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isOk());
        passwordRequest("/password/recovery/complete",
                Map.of("grantToken", grant, "password", "fixture-updated-password"), 204);
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isUnauthorized());
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void resendHoldingTheChallengeLockDefeatsConcurrentVerification() throws Exception {
        String mobile = "9100000009";
        String id = send(mobile);
        makeResendEligible(id);
        String[] replacement = new String[1];
        withBlockedRequest("select 1 from otp_challenges where challenge_id=? for update", UUID.fromString(id),
                () -> authRequest("/otp/verify", otp(mobile, id)).getResponse().getStatus(),
                () -> replacement[0] = otpService.resendChallenge(com.etfloans.backend.model.OtpPurpose.LEGACY_LOGIN,
                        mobile, id).getChallengeId().toString(), 400);
        passwordRequest("/otp/verify", otp(mobile, replacement[0]), 200);
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void passwordResetHoldingTheUserLockDefeatsConcurrentPasswordLogin() throws Exception {
        String mobile = "9100000010";
        createPasswordUser(mobile);
        String id = startLogin(mobile, TEST_PASSWORD);
        String recovery = grant("recovery", mobile);
        withBlockedRequest("select 1 from users where mobile_number=? for update", mobile,
                () -> authRequest("/password/login/verify", otp(mobile, id)).getResponse().getStatus(),
                () -> otpService.completePasswordFlow(com.etfloans.backend.model.OtpPurpose.RECOVERY,
                        recovery, "fixture-updated-password"), 400);
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void otpExpiryIsCheckedAfterWaitingForTheChallengeLock() throws Exception {
        String mobile = "9100000011";
        String id = send(mobile);
        UUID key = UUID.fromString(id);
        withBlockedRequest("select 1 from otp_challenges where challenge_id=? for update", key,
                () -> authRequest("/otp/verify", otp(mobile, id)).getResponse().getStatus(),
                () -> jdbc.update("update otp_challenges set expires_at=? where challenge_id=?", LocalDateTime.now(), key), 400);
        assertNull(challenges.findById(key).orElseThrow().getConsumedAt());
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void grantExpiryIsCheckedAfterWaitingForTheGrantLock() throws Exception {
        String mobile = "9100000012";
        String grant = grant("registration", mobile);
        withBlockedRequest("select 1 from password_grants where mobile_number=? for update", mobile,
                () -> authRequest("/password/registration/complete", Map.of("grantToken", grant, "password", TEST_PASSWORD))
                        .getResponse().getStatus(),
                () -> jdbc.update("update password_grants set expires_at=? where mobile_number=?", LocalDateTime.now(), mobile), 400);
        assertTrue(users.findByMobileNumber(mobile).isEmpty());
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void grantCompletedUnderItsLockCannotBeConsumedByTheWaitingRequest() throws Exception {
        String mobile = "9100000013";
        String grant = grant("registration", mobile);
        withBlockedRequest("select 1 from password_grants where mobile_number=? for update", mobile,
                () -> authRequest("/password/registration/complete", Map.of("grantToken", grant, "password", TEST_PASSWORD))
                        .getResponse().getStatus(),
                () -> otpService.completePasswordFlow(com.etfloans.backend.model.OtpPurpose.REGISTRATION, grant, TEST_PASSWORD),
                400);
        assertTrue(users.findByMobileNumber(mobile).isPresent());
    }

    private void withBlockedRequest(String lockSql, Object key, Callable<Integer> request,
                                    Runnable finishUnderLock, int expectedStatus) throws Exception {
        var executor = Executors.newSingleThreadExecutor();
        try {
            var result = transactions.execute(tx -> {
                int holder = jdbc.queryForObject("select pg_backend_pid()", Integer.class);
                assertEquals(1, jdbc.queryForObject(lockSql, Integer.class, key));
                var pending = executor.submit(request);
                org.awaitility.Awaitility.await().atMost(8, TimeUnit.SECONDS).until(() ->
                        jdbc.queryForObject("select count(*) from pg_stat_activity where ? = any(pg_blocking_pids(pid))",
                                Integer.class, holder) > 0);
                finishUnderLock.run();
                return pending;
            });
            assertEquals(expectedStatus, result.get(10, TimeUnit.SECONDS));
        } finally {
            executor.shutdownNow();
        }
    }

    private String grant(String flow, String mobile) throws Exception {
        String path = "/password/" + flow;
        String id = passwordRequest(path + "/start", Map.of("mobileNumber", mobile), 200).path("challengeId").asText();
        return passwordRequest(path + "/verify", otp(mobile, id), 200).path("grantToken").asText();
    }

    private String startLogin(String mobile, String password) throws Exception {
        return passwordRequest("/password/login/start", Map.of("mobileNumber", mobile, "password", password), 200)
                .path("challengeId").asText();
    }

    private String createPasswordUser(String mobile) {
        var user = new com.etfloans.backend.model.Users(UUID.randomUUID(), mobile);
        String hash = new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder(12).encode(TEST_PASSWORD);
        user.setPasswordHash(hash);
        users.save(user);
        return hash;
    }

    private Map<String, String> otp(String mobile, String id) {
        return Map.of("mobileNumber", mobile, "challengeId", id, "otp", "123456");
    }

    private void makeResendEligible(String id) {
        jdbc.update("update otp_challenges set created_at = ? where challenge_id = ?",
                LocalDateTime.now().minusMinutes(1), UUID.fromString(id));
    }

    @Autowired
    private com.etfloans.backend.service.OtpAuthenticationService otpService;

    @Autowired
    private com.etfloans.backend.repository.UsersRepository users;

    private MvcResult authRequest(String path, Map<String, String> data) throws Exception {
        return mockMvc.perform(post("/api/auth" + path)
                .header("X-API-Key", "test-demo-api-key")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(data))).andReturn();
    }

    private JsonNode passwordRequest(String path, Map<String, String> data, int expectedStatus) throws Exception {
        var response = authRequest(path, data).getResponse();
        org.junit.jupiter.api.Assertions.assertEquals(expectedStatus, response.getStatus(), path);
        return objectMapper.readTree(response.getContentAsString());
    }

    private String send(String mobileNumber) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"" + mobileNumber + "\"}"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        return body.get("challengeId").asText();
    }

    private String verifyBody(String challengeId, String mobileNumber, String otp) {
        return "{\"challengeId\":\"" + challengeId + "\","
                + "\"mobileNumber\":\"" + mobileNumber + "\","
                + "\"otp\":\"" + otp + "\"}";
    }

    @Test
    void sendReturnsChallengeAndDevelopmentOtp() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"9000000001\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.challengeId").isNotEmpty())
                .andExpect(jsonPath("$.developmentOtp").value("123456"));
    }

    @Test
    void verifyWithCorrectOtpSucceeds() throws Exception {
        String challengeId = send("9000000002");

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(challengeId, "9000000002", "123456")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.user.mobileNumber").value("9000000002"));
    }

    @Test
    void verifyWithWrongOtpReturns400() throws Exception {
        String challengeId = send("9000000003");

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(challengeId, "9000000003", "000000")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid OTP."));
    }

    @Test
    void verifyUnknownChallengeReturns400() throws Exception {
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(UUID.randomUUID().toString(), "9000000004", "123456")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void verifyExpiredChallengeReturns400() throws Exception {
        String challengeId = send("9000000005");
        OtpChallenges challenge = challenges.findByChallengeId(UUID.fromString(challengeId)).orElseThrow();
        challenge.setExpiresAt(LocalDateTime.now().minusSeconds(1));
        challenges.save(challenge);

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(challengeId, "9000000005", "123456")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(Matchers.containsString("expired")));
    }

    @Test
    void verifyAfterMaxAttemptsReturns400() throws Exception {
        String challengeId = send("9000000006");
        OtpChallenges challenge = challenges.findByChallengeId(UUID.fromString(challengeId)).orElseThrow();
        challenge.setAttemptCount(challenge.getMaxAttempts());
        challenges.save(challenge);

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(challengeId, "9000000006", "123456")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(Matchers.containsString("Maximum")));
    }

    @Test
    void sendRateLimitReturns429() throws Exception {
        String mobileNumber = "9000000007";
        send(mobileNumber);
        send(mobileNumber);
        send(mobileNumber);

        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"" + mobileNumber + "\"}"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void currentUserReturnsProfileWithValidToken() throws Exception {
        String mobileNumber = "9000000008";
        String challengeId = send(mobileNumber);

        MvcResult verifyResult = mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content(verifyBody(challengeId, mobileNumber, "123456")))
                .andExpect(status().isOk())
                .andReturn();
        String accessToken = objectMapper
                .readTree(verifyResult.getResponse().getContentAsString())
                .get("accessToken").asText();

        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mobileNumber").value(mobileNumber));
    }

    @Test
    void currentUserWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void invalidMobileReturns400() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"12345\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @Test
    void sendWithoutApiKeyReturns403() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobileNumber\":\"9000000009\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Invalid or missing API key"));
    }

    @Test
    void sendWithWrongApiKeyReturns403() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "wrong-key")
                        .content("{\"mobileNumber\":\"9000000010\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Invalid or missing API key"));
    }

    @Test
    void verifyWithoutApiKeyReturns403() throws Exception {
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"challengeId\":\"" + UUID.randomUUID() + "\",\"mobileNumber\":\"9000000011\",\"otp\":\"123456\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Invalid or missing API key"));
    }

    @Test
    void verifyWithWrongApiKeyReturns403() throws Exception {
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "wrong-key")
                        .content("{\"challengeId\":\"" + UUID.randomUUID() + "\",\"mobileNumber\":\"9000000012\",\"otp\":\"123456\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Invalid or missing API key"));
    }

    @Test
    void sendWithAndroidApiKeySucceeds() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-android-api-key")
                        .content("{\"mobileNumber\":\"9000000013\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.challengeId").isNotEmpty())
                .andExpect(jsonPath("$.developmentOtp").value("123456"));
    }

    @Test
    void verifyWithAndroidApiKeySucceeds() throws Exception {
        String challengeId = send("9000000014");

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-android-api-key")
                        .content(verifyBody(challengeId, "9000000014", "123456")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.user.mobileNumber").value("9000000014"));
    }
}
