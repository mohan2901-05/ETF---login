package com.etfloans.backend.dto;

import java.util.UUID;

public class OtpVerifyResponse {
    private boolean success;
    private String message;
    private String accessToken;
    private String tokenType;
    private int expiresInSeconds;
    private VerifyUser user;

    public OtpVerifyResponse() {
    }

    public OtpVerifyResponse(boolean success, String message, String accessToken,
                             String tokenType, int expiresInSeconds, VerifyUser user) {
        this.success = success;
        this.message = message;
        this.accessToken = accessToken;
        this.tokenType = tokenType;
        this.expiresInSeconds = expiresInSeconds;
        this.user = user;
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

    public String getAccessToken() {
        return accessToken;
    }

    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }

    public String getTokenType() {
        return tokenType;
    }

    public void setTokenType(String tokenType) {
        this.tokenType = tokenType;
    }

    public int getExpiresInSeconds() {
        return expiresInSeconds;
    }

    public void setExpiresInSeconds(int expiresInSeconds) {
        this.expiresInSeconds = expiresInSeconds;
    }

    public VerifyUser getUser() {
        return user;
    }

    public void setUser(VerifyUser user) {
        this.user = user;
    }
}