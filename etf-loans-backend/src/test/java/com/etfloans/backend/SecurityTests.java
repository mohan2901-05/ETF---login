package com.etfloans.backend;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void corsPreflightRequestSucceeds() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options("/api/auth/otp/send")
                        .header("Origin", "http://localhost:3000")
                        .header("Access-Control-Request-Method", "POST")
                        .header("Access-Control-Request-Headers", "Content-Type"))
                .andExpect(status().isOk())
                .andExpect(header().exists("Access-Control-Allow-Origin"))
                .andExpect(header().exists("Access-Control-Allow-Methods"))
                .andExpect(header().exists("Access-Control-Allow-Headers"));
    }

    @Test
    void corsRejectsUnknownOrigin() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Origin", "http://evil.com")
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"9000000001\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void healthEndpointPubliclyAccessible() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk());
    }

    @Test
    void meEndpointRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Authentication required"));
    }

    @Test
    void meEndpointRejectsInvalidToken() throws Exception {
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid or expired token"));
    }

    @Test
    void logoutWithoutTokenSucceeds() throws Exception {
        mockMvc.perform(post("/api/auth/logout"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Logged out successfully"));
    }

    @Test
    void sendOtpRequiresValidMobileNumber() throws Exception {
        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"123\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @Test
    void verifyOtpRequiresValidOtpFormat() throws Exception {
        String challengeId = UUID.randomUUID().toString();
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"challengeId\":\"" + challengeId + "\",\"mobileNumber\":\"9000000001\",\"otp\":\"123\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("OTP must be 6 digits."));
    }

    @Test
    void verifyOtpRequiresChallengeId() throws Exception {
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"9000000001\",\"otp\":\"123456\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Challenge ID is required."));
    }

    @Test
    void rateLimitIncludesRetryAfterHeader() throws Exception {
        String mobileNumber = "9000000020";
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/auth/otp/send")
                            .contentType(MediaType.APPLICATION_JSON)
                            .header("X-API-Key", "test-demo-api-key")
                            .content("{\"mobileNumber\":\"" + mobileNumber + "\"}"))
                    .andExpect(status().isOk());
        }

        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"" + mobileNumber + "\"}"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void verifyRateLimitIncludesRetryAfterHeader() throws Exception {
        String challengeId = sendAndVerify("9000000021");
        for (int i = 0; i < 10; i++) {
            mockMvc.perform(post("/api/auth/otp/verify")
                            .contentType(MediaType.APPLICATION_JSON)
                            .header("X-API-Key", "test-demo-api-key")
                            .content("{\"challengeId\":\"" + challengeId + "\",\"mobileNumber\":\"9000000021\",\"otp\":\"000000\"}"))
                    .andExpect(status().isBadRequest());
        }

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"challengeId\":\"" + challengeId + "\",\"mobileNumber\":\"9000000021\",\"otp\":\"000000\"}"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void challengeIdMustBeValidUuid() throws Exception {
        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"challengeId\":\"not-a-uuid\",\"mobileNumber\":\"9000000001\",\"otp\":\"123456\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid challenge ID."));
    }

    private String sendAndVerify(String mobileNumber) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-API-Key", "test-demo-api-key")
                        .content("{\"mobileNumber\":\"" + mobileNumber + "\"}"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        return body.get("challengeId").asText();
    }
}