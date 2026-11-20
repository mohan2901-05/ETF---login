package com.etfloans.backend;

import com.etfloans.backend.model.OtpChallenges;
import com.etfloans.backend.repository.OtpChallengesRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.UUID;

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
