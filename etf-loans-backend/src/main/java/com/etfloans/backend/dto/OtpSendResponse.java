package com.etfloans.backend.dto;

import java.util.UUID;

public class OtpSendResponse {
    private boolean success;
    private String message;
    private UUID challengeId;
    private int expirySeconds;
    private int resendAfterSeconds;
    private String developmentOtp;

    public OtpSendResponse() {
    }

    public OtpSendResponse(boolean success, String message, UUID challengeId,
                           int expirySeconds, int resendAfterSeconds) {
        this.success = success;
        this.message = message;
        this.challengeId = challengeId;
        this.expirySeconds = expirySeconds;
        this.resendAfterSeconds = resendAfterSeconds;
    }

    public OtpSendResponse(boolean success, String message, UUID challengeId,
                           int expirySeconds, int resendAfterSeconds, String developmentOtp) {
        this.success = success;
        this.message = message;
        this.challengeId = challengeId;
        this.expirySeconds = expirySeconds;
        this.resendAfterSeconds = resendAfterSeconds;
        this.developmentOtp = developmentOtp;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public UUID getChallengeId() {
        return challengeId;
    }

    public void setChallengeId(UUID challengeId) {
        this.challengeId = challengeId;
    }

    public int getExpirySeconds() {
        return expirySeconds;
    }

    public void setExpirySeconds(int expirySeconds) {
        this.expirySeconds = expirySeconds;
    }

    public int getResendAfterSeconds() {
        return resendAfterSeconds;
    }

    public void setResendAfterSeconds(int resendAfterSeconds) {
        this.resendAfterSeconds = resendAfterSeconds;
    }

    public String getDevelopmentOtp() {
        return developmentOtp;
    }

    public void setDevelopmentOtp(String developmentOtp) {
        this.developmentOtp = developmentOtp;
    }
}