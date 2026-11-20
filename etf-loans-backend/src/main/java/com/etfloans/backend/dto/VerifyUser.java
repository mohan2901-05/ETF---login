package com.etfloans.backend.dto;

import java.util.UUID;

public class VerifyUser {
    private UUID id;
    private String mobileNumber;
    private String name;
    private boolean isNewUser;

    public VerifyUser() {
    }

    public VerifyUser(UUID id, String mobileNumber, String name, boolean isNewUser) {
        this.id = id;
        this.mobileNumber = mobileNumber;
        this.name = name;
        this.isNewUser = isNewUser;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getMobileNumber() {
        return mobileNumber;
    }

    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public boolean isNewUser() {
        return isNewUser;
    }

    public void setNewUser(boolean newUser) {
        isNewUser = newUser;
    }
}